"""cocotb TB para canny_control: Canny en streaming (NMS + histeresis 1-salto).
Transmite una imagen rampa+escalon, compara edge/class de todos los pixeles
interiores contra el golden numpy (mismo gradiente, cuadrante fixed-point, NMS,
doble umbral, histeresis 1-salto)."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
import numpy as np

H = W = 14; LOW, HIGH = 40, 200

def make_img():
    img = np.zeros((H, W), int)
    for i in range(H):
        for j in range(W):
            img[i, j] = min(255, 6*i + (120 if i >= 9 else 0))
    return img

def grad(img, r, c):
    g = lambda i, j: int(img[i, j])
    gx = (g(r-1,c+1)-g(r-1,c-1)) + 2*(g(r,c+1)-g(r,c-1)) + (g(r+1,c+1)-g(r+1,c-1))
    gy = (g(r+1,c-1)-g(r-1,c-1)) + 2*(g(r+1,c)-g(r-1,c)) + (g(r+1,c+1)-g(r-1,c+1))
    ax, ay = abs(gx), abs(gy); mag = ax + ay
    ay8 = ay << 8
    q = 0 if ay8 < ax*106 else (2 if ay8 > ax*618 else (1 if (gx < 0) == (gy < 0) else 3))
    return mag, q

def cls(img, r, c):
    m, q = grad(img, r, c); mg = lambda i, j: grad(img, i, j)[0]
    if   q == 0: n1, n2 = mg(r,c+1), mg(r,c-1)
    elif q == 1: n1, n2 = mg(r-1,c+1), mg(r+1,c-1)
    elif q == 2: n1, n2 = mg(r-1,c), mg(r+1,c)
    else:        n1, n2 = mg(r-1,c-1), mg(r+1,c+1)
    sup = m if (m >= n1 and m >= n2) else 0
    return 2 if sup >= HIGH else (1 if sup >= LOW else 0)

def golden(img):
    E, C = [], []
    for cr in range(3, H-3):
        for cc in range(3, W-3):
            c0 = cls(img, cr, cc)
            e = 1 if c0 == 2 else (int(any(cls(img, cr+dr, cc+dc) == 2
                    for dr in (-1,0,1) for dc in (-1,0,1) if (dr or dc))) if c0 == 1 else 0)
            E.append(e); C.append(c0)
    return E, C

@cocotb.test()
async def canny_stream(dut):
    img = make_img(); eE, eC = golden(img)
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    dut.nreset_i.value = 0; dut.px_valid_i.value = 0; dut.px_i.value = 0
    dut.low_i.value = LOW; dut.high_i.value = HIGH
    dut.img_w_i.value = W
    await FallingEdge(dut.clk_i); dut.nreset_i.value = 1
    flat = img.flatten().tolist()
    gE, gC = [], []

    async def drive():
        for px in flat:
            await FallingEdge(dut.clk_i); dut.px_i.value = int(px); dut.px_valid_i.value = 1
        await FallingEdge(dut.clk_i); dut.px_valid_i.value = 0
    cocotb.start_soon(drive())

    for _ in range(len(flat) + 8):
        await RisingEdge(dut.clk_i)
        if int(dut.out_valid_o.value) == 1:
            gE.append(int(dut.edge_o.value)); gC.append(int(dut.class_o.value))

    assert len(gE) == len(eE), f"salidas {len(gE)} != {len(eE)}"
    n = len(eE)
    oke = sum(gE[i] == eE[i] for i in range(n)); okc = sum(gC[i] == eC[i] for i in range(n))
    dut._log.info(f"edge {oke}/{n} ({100*oke/n:.1f}%)  class {okc}/{n} ({100*okc/n:.1f}%)  "
                  f"clases={ {k:eC.count(k) for k in (0,1,2)} }")
    assert oke == n and okc == n, "mismatch vs golden"
    dut._log.info("CANNY CONTROL (cocotb, NMS+histeresis streaming): ALL TESTS PASSED")
