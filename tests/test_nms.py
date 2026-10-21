"""cocotb testbench para nms_core (Supresion de No-Maximos, combinacional).
Prueba casos a mano (cresta vertical, no-maximo) y muchos aleatorios contra un
golden en python; verifica mag_o y keep_o para las 8 direcciones del compas.

Convencion de direccion (igual que sobel_compass_core):
  0=N 1=NE 2=E 3=SE 4=S 5=SW 6=W 7=NW
Ventana 3x3 row-major:  w0 w1 w2 / w3 w4 w5 / w6 w7 w8   (w4 = centro)
"""
import cocotb
from cocotb.triggers import Timer
import random

MAGW = 8
# dir -> (indice vecino a, indice vecino b) en la ventana row-major
PAIRS = {0: (1, 7), 1: (2, 6), 2: (3, 5), 3: (0, 8),
         4: (1, 7), 5: (2, 6), 6: (3, 5), 7: (0, 8)}


def pack(w):
    v = 0
    for k in range(9):
        v |= (int(w[k]) & ((1 << MAGW) - 1)) << (MAGW * k)
    return v


def golden(w, d):
    a, b = PAIRS[d]
    keep = (w[4] >= w[a]) and (w[4] >= w[b])
    return (w[4] if keep else 0), int(keep)


async def check(dut, w, d, tag=""):
    dut.mag9_i.value = pack(w)
    dut.dir_i.value = d
    await Timer(1, units="ns")
    emag, ekeep = golden(w, d)
    gmag, gkeep = int(dut.mag_o.value), int(dut.keep_o.value)
    assert (gmag, gkeep) == (emag, ekeep), \
        f"{tag} dir={d} w={w}: hw=({gmag},{gkeep}) exp=({emag},{ekeep})"


@cocotb.test()
async def nms_hand_cases(dut):
    # cresta vertical: centro fuerte; en eje vertical (N) los vecinos w1,w7 son
    # debiles -> se conserva.
    w = [10, 20, 10,
         10, 200, 10,
         10, 20, 10]
    await check(dut, w, 0, "cresta/N")     # keep: 200>=20 y 200>=20
    await check(dut, w, 2, "cresta/E")     # keep: 200>=10 y 200>=10

    # el centro NO es maximo en su eje horizontal (E): w3=100, w5=120 > 50
    w2 = [0, 0, 0,
          100, 50, 120,
          0, 0, 0]
    await check(dut, w2, 2, "no-max/E")    # suprimido -> (0,0)

    # empate: con '>=' el centro empatado se conserva
    w3 = [0, 50, 0,
          0, 50, 0,
          0, 50, 0]
    await check(dut, w3, 0, "empate/N")    # 50>=50 -> keep
    dut._log.info("NMS hand cases OK")


@cocotb.test()
async def nms_random(dut):
    random.seed(1)
    n = 0
    for _ in range(3000):
        w = [random.randint(0, 255) for _ in range(9)]
        d = random.randint(0, 7)
        await check(dut, w, d)
        n += 1
    dut._log.info(f"NMS random: {n}/{n} OK")
    dut._log.info("NMS CORE (cocotb): ALL TESTS PASSED")
