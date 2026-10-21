// =============================================================================
// canny_full_core.sv  -- Canny COMPLETO por pixel, COMBINACIONAL.
//   Entrada: ventana 7x7 de gris (ya suavizado).  Por que 7x7:
//     edge(centro) <- histeresis(3x3 de class) <- NMS(3x3 de mag) <- grad(3x3 de gris)
//     => 3+2+2 = 7.  Asi se evita encadenar 3 ventanas en streaming.
//   Etapas:
//     1) gradiente Sobel en el 5x5 interior  -> mag=|Gx|+|Gy| y CUADRANTE del angulo
//     2) NMS en el 3x3 interior  (compara el centro contra sus 2 vecinos segun cuadrante)
//     3) doble umbral -> class (0 nada / 1 debil / 2 fuerte)
//     4) histeresis 1-salto: el centro debil es borde si algun vecino (8) es fuerte
//   El cuadrante usa coeficientes constantes (106/256~tan22.5, 618/256~tan67.5),
//   solo shifts/sumas (sin atan2 ni division).  NMS+histeresis-1salto = aproximacion
//   streamable; la histeresis transitiva completa seria iterativa (nota en README).
// =============================================================================
`default_nettype none
module canny_full_core #(parameter integer PIX=8, parameter integer MAGW=12)(
    input  wire [49*PIX-1:0] gwin_i,        // 7x7 gris, row-major (r*7+c), r,c=0..6
    input  wire [MAGW-1:0]   low_i, high_i,
    output wire              edge_o,
    output wire [1:0]        class_o        // clase del centro (3,3)
);
    function automatic signed [PIX:0] gs(input [49*PIX-1:0] w, input integer r, input integer c);
        gs = $signed({1'b0, w[PIX*(r*7+c) +: PIX]});
    endfunction

    // ---- 1) gradiente: mag y cuadrante en el 5x5 interior (r,c = 1..5) ----
    wire [MAGW-1:0] mag  [1:5][1:5];
    wire [1:0]      quad [1:5][1:5];
    genvar r,c;
    generate for (r=1;r<=5;r=r+1) for (c=1;c<=5;c=c+1) begin: grad
        wire signed [PIX+3:0] gx = (gs(gwin_i,r-1,c+1)-gs(gwin_i,r-1,c-1))
                                 + ((gs(gwin_i,r  ,c+1)-gs(gwin_i,r  ,c-1))<<<1)
                                 +  (gs(gwin_i,r+1,c+1)-gs(gwin_i,r+1,c-1));
        wire signed [PIX+3:0] gy = (gs(gwin_i,r+1,c-1)-gs(gwin_i,r-1,c-1))
                                 + ((gs(gwin_i,r+1,c  )-gs(gwin_i,r-1,c  ))<<<1)
                                 +  (gs(gwin_i,r+1,c+1)-gs(gwin_i,r-1,c+1));
        wire [PIX+3:0] ax = gx[PIX+3] ? (~gx+1'b1) : gx;
        wire [PIX+3:0] ay = gy[PIX+3] ? (~gy+1'b1) : gy;
        assign mag[r][c] = ax + ay;
        // cuadrante del angulo (0=horiz E-W,1=45,2=vert N-S,3=135)
        wire [PIX+12:0] ay8  = ay << 8;
        wire [PIX+12:0] ax_lo = ax*106;     // tan(22.5)*256
        wire [PIX+12:0] ax_hi = ax*618;     // tan(67.5)*256
        wire same = (gx[PIX+3] == gy[PIX+3]);
        assign quad[r][c] = (ay8 < ax_lo) ? 2'd0 :
                            (ay8 > ax_hi) ? 2'd2 :
                            (same ? 2'd1 : 2'd3);
    end endgenerate

    // ---- 2)+3) NMS + doble umbral en el 3x3 interior (r,c = 2..4) ----
    wire [1:0] cls [2:4][2:4];
    generate for (r=2;r<=4;r=r+1) for (c=2;c<=4;c=c+1) begin: nms
        wire [MAGW-1:0] m  = mag[r][c];
        wire [MAGW-1:0] n1 = (quad[r][c]==2'd0) ? mag[r][c+1] :
                             (quad[r][c]==2'd1) ? mag[r-1][c+1] :
                             (quad[r][c]==2'd2) ? mag[r-1][c]   : mag[r-1][c-1];
        wire [MAGW-1:0] n2 = (quad[r][c]==2'd0) ? mag[r][c-1] :
                             (quad[r][c]==2'd1) ? mag[r+1][c-1] :
                             (quad[r][c]==2'd2) ? mag[r+1][c]   : mag[r+1][c+1];
        wire keep = (m >= n1) && (m >= n2);
        wire [MAGW-1:0] sup = keep ? m : {MAGW{1'b0}};
        assign cls[r][c] = (sup >= high_i) ? 2'd2 : (sup >= low_i) ? 2'd1 : 2'd0;
    end endgenerate

    // ---- 4) histeresis 1-salto en el centro (3,3) ----
    wire any_strong = (cls[2][2]==2'd2)|(cls[2][3]==2'd2)|(cls[2][4]==2'd2)|
                      (cls[3][2]==2'd2)|                  (cls[3][4]==2'd2)|
                      (cls[4][2]==2'd2)|(cls[4][3]==2'd2)|(cls[4][4]==2'd2);
    assign class_o = cls[3][3];
    assign edge_o  = (cls[3][3]==2'd2) ? 1'b1 : (cls[3][3]==2'd1) ? any_strong : 1'b0;
endmodule
`default_nettype wire
