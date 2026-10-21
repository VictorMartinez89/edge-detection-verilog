// =============================================================================
// sobel_compass_core.sv  -- 8 filtros Sobel direccionales (compass / brujula)
//   N, NE, E, SE, S, SW, W, NW  (rotaciones de 45 grados del kernel Sobel 3x3)
//
// Estilo Diana (sobel_core.sv): 100% combinacional, SIN multiplicadores:
//   los coeficientes del kernel {-2,-1,0,1,2} se hacen con  + , -  y  << 1 (x2).
//
// Ventana 3x3 empacada row-major en window_i  (window_i[PIX*k +: PIX] = pixel k):
//        p0 p1 p2
//        p3 p4 p5
//        p6 p7 p8
//
// Nota (importante para la tesis): la mascara de una direccion es el NEGATIVO
//  de su opuesta (S = -N, W = -E, ...), asi que |conv| coincide en pares. La
//  direccion real esta en el SIGNO; aqui se reporta |conv| (como en el notebook,
//  Parte 5/8) y la direccion ganadora por argmax.
// =============================================================================
`default_nettype none
module sobel_compass_core #(
    parameter integer PIX = 8                       // bits por pixel (gris)
)(
    input  wire [9*PIX-1:0]      window_i,          // ventana 3x3 empacada
    output wire [8*PIX-1:0]      mag_o,             // 8 magnitudes |conv| saturadas a PIX bits
    output wire [PIX-1:0]        compass_o,         // magnitud de la direccion mas fuerte
    output wire [2:0]            dir_o              // 0=N 1=NE 2=E 3=SE 4=S 5=SW 6=W 7=NW
);
    // --- desempacar pixeles (con signo) ---
    wire signed [PIX:0] p0 = $signed({1'b0, window_i[PIX*0 +: PIX]});
    wire signed [PIX:0] p1 = $signed({1'b0, window_i[PIX*1 +: PIX]});
    wire signed [PIX:0] p2 = $signed({1'b0, window_i[PIX*2 +: PIX]});
    wire signed [PIX:0] p3 = $signed({1'b0, window_i[PIX*3 +: PIX]});
    wire signed [PIX:0] p5 = $signed({1'b0, window_i[PIX*5 +: PIX]});
    wire signed [PIX:0] p6 = $signed({1'b0, window_i[PIX*6 +: PIX]});
    wire signed [PIX:0] p7 = $signed({1'b0, window_i[PIX*7 +: PIX]});
    wire signed [PIX:0] p8 = $signed({1'b0, window_i[PIX*8 +: PIX]});
    // p4 (centro) no se usa: el coeficiente central es 0 en todas las mascaras.

    // --- 8 gradientes direccionales (solo +, -, <<1) ---
    wire signed [PIX+3:0] gN  = (p0 + (p1<<1) + p2) - (p6 + (p7<<1) + p8);
    wire signed [PIX+3:0] gNE = ((p0<<1) + p1 + p3) - (p5 + (p8<<1) + p7);
    wire signed [PIX+3:0] gE  = (p0 + (p3<<1) + p6) - (p2 + (p5<<1) + p8);
    wire signed [PIX+3:0] gSE = (p3 + (p6<<1) + p7) - (p1 + (p2<<1) + p5);
    wire signed [PIX+3:0] gS  = -gN;
    wire signed [PIX+3:0] gSW = -gNE;
    wire signed [PIX+3:0] gW  = -gE;
    wire signed [PIX+3:0] gNW = -gSE;

    // --- valor absoluto por complemento a 2 (como Diana: ~x+1) ---
    function automatic [PIX+3:0] absv(input signed [PIX+3:0] x);
        absv = x[PIX+3] ? (~x + 1'b1) : x;
    endfunction

    wire [PIX+3:0] aN=absv(gN), aNE=absv(gNE), aE=absv(gE), aSE=absv(gSE),
                   aS=absv(gS), aSW=absv(gSW), aW=absv(gW), aNW=absv(gNW);

    // --- saturacion a PIX bits (8) ---
    localparam [PIX-1:0] MAXV = {PIX{1'b1}};
    function automatic [PIX-1:0] sat(input [PIX+3:0] x);
        sat = (|x[PIX+3:PIX]) ? MAXV : x[PIX-1:0];
    endfunction

    assign mag_o[PIX*0 +: PIX] = sat(aN);
    assign mag_o[PIX*1 +: PIX] = sat(aNE);
    assign mag_o[PIX*2 +: PIX] = sat(aE);
    assign mag_o[PIX*3 +: PIX] = sat(aSE);
    assign mag_o[PIX*4 +: PIX] = sat(aS);
    assign mag_o[PIX*5 +: PIX] = sat(aSW);
    assign mag_o[PIX*6 +: PIX] = sat(aW);
    assign mag_o[PIX*7 +: PIX] = sat(aNW);

    // --- direccion ganadora (argmax sobre las 8) y su magnitud ---
    wire [PIX+3:0] m [0:7];
    assign m[0]=aN; assign m[1]=aNE; assign m[2]=aE; assign m[3]=aSE;
    assign m[4]=aS; assign m[5]=aSW; assign m[6]=aW; assign m[7]=aNW;
    integer k;
    reg [PIX+3:0] best; reg [2:0] bestd;
    always @* begin
        best = m[0]; bestd = 3'd0;
        for (k=1;k<8;k=k+1) if (m[k] > best) begin best = m[k]; bestd = k[2:0]; end
    end
    assign compass_o = sat(best);
    assign dir_o     = bestd;
endmodule
`default_nettype wire
