// =============================================================================
// canny_grad_threshold_core.sv
//   Etapas FACTIBLES de Canny en hardware (combinacional, por pixel):
//     - doble umbral:  G_low  = mag si mag>=low  (debiles+fuertes)
//                      G_high = mag si mag>=high (solo fuertes / semillas)
//     - clasificacion: 00=nada  01=debil  10=fuerte
//     - combinacion que pediste:  combo = sqrt(G_low + G_high)
//
//   IMPORTANTE (tesis): la SUPRESION DE NO-MAXIMOS y la HISTERESIS de Canny
//   NO son por-pixel: necesitan vecindario orientado + conectividad sobre todo
//   el frame (buffers de linea / 2 pasadas). Eso es un modulo aparte (control
//   tipo sobel_control + memoria), no cabe en una etapa combinacional. Aqui
//   queda el datapath; el control de histeresis es trabajo futuro de la tesis.
// =============================================================================
`default_nettype none
module canny_grad_threshold_core #(
    parameter integer MAGW = 12          // bits de la magnitud del gradiente
)(
    input  wire [MAGW-1:0]   mag_i,      // |G| del sobel_core (o sqrt(Gx^2+Gy^2))
    input  wire [MAGW-1:0]   low_i,      // umbral bajo
    input  wire [MAGW-1:0]   high_i,     // umbral alto  (high>=low, razon ~2:1)
    output wire [MAGW-1:0]   g_low_o,
    output wire [MAGW-1:0]   g_high_o,
    output wire [1:0]        class_o,    // 00 nada / 01 debil / 10 fuerte
    output wire [(MAGW+1)/2:0] combo_o   // sqrt(G_low + G_high)
);
    wire is_strong = (mag_i >= high_i);
    wire is_weak   = (mag_i >= low_i) && !is_strong;

    assign g_low_o  = (mag_i >= low_i)  ? mag_i : {MAGW{1'b0}};
    assign g_high_o = is_strong         ? mag_i : {MAGW{1'b0}};
    assign class_o  = is_strong ? 2'b10 : (is_weak ? 2'b01 : 2'b00);

    // sqrt(G_low + G_high): la suma cabe en MAGW+1 bits -> isqrt de ancho par
    localparam integer SW = ((MAGW+1+1)/2)*2;       // ancho par >= MAGW+1
    wire [SW-1:0] sum_ext = { {(SW-(MAGW+1)){1'b0}}, ({1'b0,g_low_o} + {1'b0,g_high_o}) };
    isqrt #(.W(SW)) u_sqrt (.x_i(sum_ext), .y_o(combo_o[SW/2-1:0]));
endmodule
`default_nettype wire
