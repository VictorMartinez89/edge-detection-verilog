// =============================================================================
// gaussian_core.sv  -- suavizado Gaussiano 3x3 / 5x5 / 7x7  (front-end de Canny)
//
// Kernels BINOMIALES (Pascal) -> separables y con suma POTENCIA DE 2:
//   3x3: 1D [1,2,1]            sum=16   -> dividir = >>4
//   5x5: 1D [1,4,6,4,1]        sum=256  -> >>8
//   7x7: 1D [1,6,15,20,15,6,1] sum=4096 -> >>12
// Asi la division es un corrimiento (>>), SIN multiplicador, estilo Diana.
// Cada modulo es combinacional y recibe la ventana NxN empacada row-major.
// Coeficientes hechos con +,-,<< :  4=<<2  6=<<2+<<1  15=<<4-1  20=<<4+<<2
// =============================================================================
`default_nettype none

// ---- 1D helpers (suma ponderada de una fila/columna) -------------------------
// k3 = a + 2b + c
// k5 = a + 4b + 6c + 4d + e
// k7 = a + 6b + 15c + 20d + 15e + 6f + g

module gaussian3x3 #(parameter integer PIX=8)(
    input  wire [9*PIX-1:0] win_i,
    output wire [PIX-1:0]   gray_o
);
    function automatic [PIX+7:0] k3(input [PIX+7:0] a,b,c);
        k3 = a + (b<<1) + c;
    endfunction
    wire [PIX-1:0] p [0:8];
    genvar i; generate for(i=0;i<9;i++) assign p[i]=win_i[PIX*i +: PIX]; endgenerate
    // filas
    wire [PIX+7:0] r0=k3(p[0],p[1],p[2]);
    wire [PIX+7:0] r1=k3(p[3],p[4],p[5]);
    wire [PIX+7:0] r2=k3(p[6],p[7],p[8]);
    wire [PIX+7:0] acc=k3(r0,r1,r2);          // combina filas con el mismo [1,2,1]
    assign gray_o = acc >> 4;                  // /16
endmodule

module gaussian5x5 #(parameter integer PIX=8)(
    input  wire [25*PIX-1:0] win_i,
    output wire [PIX-1:0]    gray_o
);
    function automatic [PIX+11:0] k5(input [PIX+11:0] a,b,c,d,e);
        k5 = a + (b<<2) + ((c<<2)+(c<<1)) + (d<<2) + e;   // 1,4,6,4,1
    endfunction
    wire [PIX-1:0] p [0:24];
    genvar i; generate for(i=0;i<25;i++) assign p[i]=win_i[PIX*i +: PIX]; endgenerate
    wire [PIX+11:0] r0=k5(p[0],p[1],p[2],p[3],p[4]);
    wire [PIX+11:0] r1=k5(p[5],p[6],p[7],p[8],p[9]);
    wire [PIX+11:0] r2=k5(p[10],p[11],p[12],p[13],p[14]);
    wire [PIX+11:0] r3=k5(p[15],p[16],p[17],p[18],p[19]);
    wire [PIX+11:0] r4=k5(p[20],p[21],p[22],p[23],p[24]);
    wire [PIX+11:0] acc=k5(r0,r1,r2,r3,r4);
    assign gray_o = acc >> 8;                  // /256
endmodule

module gaussian7x7 #(parameter integer PIX=8)(
    input  wire [49*PIX-1:0] win_i,
    output wire [PIX-1:0]    gray_o
);
    function automatic [PIX+15:0] k7(input [PIX+15:0] a,b,c,d,e,f,g);
        // 1,6,15,20,15,6,1   con  6=<<2+<<1  15=<<4-1  20=<<4+<<2
        k7 = a + ((b<<2)+(b<<1)) + ((c<<4)-c) + ((d<<4)+(d<<2))
               + ((e<<4)-e) + ((f<<2)+(f<<1)) + g;
    endfunction
    wire [PIX-1:0] p [0:48];
    genvar i; generate for(i=0;i<49;i++) assign p[i]=win_i[PIX*i +: PIX]; endgenerate
    wire [PIX+15:0] r [0:6];
    genvar j; generate for(j=0;j<7;j++)
        assign r[j]=k7(p[7*j+0],p[7*j+1],p[7*j+2],p[7*j+3],p[7*j+4],p[7*j+5],p[7*j+6]);
    endgenerate
    wire [PIX+15:0] acc=k7(r[0],r[1],r[2],r[3],r[4],r[5],r[6]);
    assign gray_o = acc >> 12;                 // /4096
endmodule
`default_nettype wire
