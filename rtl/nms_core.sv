// =============================================================================
// nms_core.sv  --  Supresion de No-Maximos (NMS) de Canny, COMBINACIONAL por pixel.
//   Recibe la ventana 3x3 de MAGNITUDES (row-major) + la direccion del gradiente
//   (mismos 8 compases que sobel_compass_core: 0=N 1=NE 2=E 3=SE 4=S 5=SW 6=W 7=NW)
//   y deja pasar el pixel central solo si es maximo local a lo largo de esa
//   direccion; si no, lo suprime (0). Adelgaza el borde a 1 pixel de ancho.
//
//   Ventana 3x3 empacada row-major (w[k] = mag9_i[MAGW*k +: MAGW]):
//        w0 w1 w2       NW  N  NE
//        w3 w4 w5   =    W  .  E     (w4 = centro)
//        w6 w7 w8       SW  S  SE
//
//   Pares opuestos comparten eje (dir y dir+4 dan el mismo par de vecinos):
//     N /S  (0/4): eje vertical    -> w1 (N)  , w7 (S)
//     NE/SW (1/5): eje diagonal /  -> w2 (NE) , w6 (SW)
//     E /W  (2/6): eje horizontal  -> w3 (W)  , w5 (E)
//     SE/NW (3/7): eje diagonal \  -> w0 (NW) , w8 (SE)
//
//   Nota (tesis): comparar |grad| del centro contra el |grad| de los 2 vecinos en
//   la direccion del gradiente es la definicion del NMS. Con '>=' en ambos lados,
//   una meseta de iguales se conserva; para adelgazar mas, usar '>' en un lado.
// =============================================================================
`default_nettype none
module nms_core #(
    parameter integer MAGW = 8
)(
    input  wire [9*MAGW-1:0] mag9_i,     // 3x3 de magnitudes, row-major
    input  wire [2:0]        dir_i,      // compas del gradiente (0=N..7=NW)
    output reg  [MAGW-1:0]   mag_o,      // w4 si es maximo local, si no 0
    output reg               keep_o      // 1 = se mantiene el borde
);
    // --- desempacar la ventana ---
    wire [MAGW-1:0] w0 = mag9_i[MAGW*0 +: MAGW];
    wire [MAGW-1:0] w1 = mag9_i[MAGW*1 +: MAGW];
    wire [MAGW-1:0] w2 = mag9_i[MAGW*2 +: MAGW];
    wire [MAGW-1:0] w3 = mag9_i[MAGW*3 +: MAGW];
    wire [MAGW-1:0] w4 = mag9_i[MAGW*4 +: MAGW];   // centro
    wire [MAGW-1:0] w5 = mag9_i[MAGW*5 +: MAGW];
    wire [MAGW-1:0] w6 = mag9_i[MAGW*6 +: MAGW];
    wire [MAGW-1:0] w7 = mag9_i[MAGW*7 +: MAGW];
    wire [MAGW-1:0] w8 = mag9_i[MAGW*8 +: MAGW];

    reg [MAGW-1:0] a, b;   // los dos vecinos segun la direccion
    always @* begin
        case (dir_i)
            3'd0: begin a = w1; b = w7; end  // N  -> vertical
            3'd1: begin a = w2; b = w6; end  // NE -> diagonal /
            3'd2: begin a = w3; b = w5; end  // E  -> horizontal
            3'd3: begin a = w0; b = w8; end  // SE -> diagonal \
            3'd4: begin a = w1; b = w7; end  // S  == eje N
            3'd5: begin a = w2; b = w6; end  // SW == eje NE
            3'd6: begin a = w3; b = w5; end  // W  == eje E
            3'd7: begin a = w0; b = w8; end  // NW == eje SE
            default: begin a = w3; b = w5; end
        endcase

        if ((w4 >= a) && (w4 >= b)) begin
            mag_o  = w4;             // maximo local -> se conserva
            keep_o = 1'b1;
        end else begin
            mag_o  = {MAGW{1'b0}};   // suprimido -> adelgaza el borde
            keep_o = 1'b0;
        end
    end
endmodule
`default_nettype wire
