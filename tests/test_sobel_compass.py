"""cocotb testbench para sobel_compass_control (8 direcciones, ventana deslizante).
Transmite una imagen en raster, captura las salidas interiores y las compara
contra el golden numpy (mismos kernels, abs, argmax sobre crudo, mag saturada a 255)."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
import numpy as np

H, W = 8, 8
KER = {"N":[[1,2,1],[0,0,0],[-1,-2,-1]], "NE":[[2,1,0],[1,0,-1],[0,-1,-2]],
       "E":[[1,0,-1],[2,0,-2],[1,0,-1]], "SE":[[0,-1,-2],[1,0,-1],[2,1,0]],
       "S":[[-1,-2,-1],[0,0,0],[1,2,1]], "SW":[[-2,-1,0],[-1,0,1],[0,1,2]],
       "W":[[-1,0,1],[-2,0,2],[-1,0,1]], "NW":[[0,1,2],[-1,0,1],[-2,-1,0]]}
ORDER = ["N","NE","E","SE","S","SW","W","NW"]

def make_image():
    r = np.arange(H)[:,None]; c = np.arange(W)[None,:]
    return ((r*37 + c*53 + r*c*11) % 256).astype(int)

def golden(img):
    mags, dirs = [], []
    for cr in range(1, H-1):
        for cc in range(1, W-1):
            win = img[cr-1:cr+2, cc-1:cc+2]
            raw = [abs(int((win*np.array(KER[d])).sum())) for d in ORDER]
            d = int(np.argmax(raw)); dirs.append(d); mags.append(min(255, raw[d]))
    return mags, dirs

@cocotb.test()
async def compass_stream(dut):
    img = make_image(); emag, edir = golden(img)
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    dut.nreset_i.value = 0; dut.px_valid_i.value = 0; dut.px_i.value = 0
    await FallingEdge(dut.clk_i); dut.img_w_i.value = W
    dut.nreset_i.value = 1

    flat = img.flatten().tolist()
    got_mag, got_dir = [], []

    async def driver():
        for px in flat:
            await FallingEdge(dut.clk_i)
            dut.px_i.value = int(px); dut.px_valid_i.value = 1
        await FallingEdge(dut.clk_i); dut.px_valid_i.value = 0

    cocotb.start_soon(driver())
    # muestrear salidas en cada flanco de subida mientras out_valid_o
    for _ in range(len(flat) + 8):
        await RisingEdge(dut.clk_i)
        if int(dut.out_valid_o.value) == 1:
            got_mag.append(int(dut.mag_o.value)); got_dir.append(int(dut.dir_o.value))

    n = min(len(got_mag), len(emag))
    assert len(got_mag) == len(emag), f"salidas {len(got_mag)} != esperadas {len(emag)}"
    okm = sum(got_mag[i] == emag[i] for i in range(n))
    okd = sum(got_dir[i] == edir[i] for i in range(n))
    dut._log.info(f"mag {okm}/{n} ({100*okm/n:.1f}%)  dir {okd}/{n} ({100*okd/n:.1f}%)")
    assert okm == n and okd == n, "mismatch vs golden"
    dut._log.info("COMPASS CONTROL (cocotb): ALL TESTS PASSED")
