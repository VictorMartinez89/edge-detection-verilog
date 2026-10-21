// =============================================================================
// sobel_compass_control.sv
//   Controlador de VENTANA DESLIZANTE 3x3 (line buffers) para el stream de pixeles.
//   Igual idea que sobel_control.sv de Diana, pero alimenta sobel_compass_core
//   (8 direcciones). Recibe pixeles en raster (fila por fila); por cada pixel
//   interior valido entrega la magnitud compass + la direccion ganadora.
//
//   - 2 line buffers guardan las 2 filas anteriores -> ventana 3x3 sin re-leer.
//   - out_valid_o se activa solo en pixeles INTERIORES (col>=2 y row>=2): es la
//     convolucion "valida" (sin bordes), igual que el notebook.
// =============================================================================
`default_nettype none
module sobel_compass_control #(
    parameter integer PIX   = 8,
    parameter integer MAX_IMG_W = 1024     // ancho maximo (dimensiona line buffers)
)(
    input  wire             clk_i,
    input  wire             nreset_i,     // activo-bajo (estilo Diana)
    input  wire [15:0]      img_w_i,      // ancho de imagen en RUNTIME
    input  wire             px_valid_i,
    input  wire [PIX-1:0]   px_i,
    output reg              out_valid_o,
    output wire [PIX-1:0]   mag_o,        // magnitud compass (direccion mas fuerte)
    output wire [2:0]       dir_o,        // 0=N..7=NW
    output wire [8*PIX-1:0] mags8_o       // las 8 magnitudes |conv|
);
    // line buffers: line1 = fila (row-1), line2 = fila (row-2)
    reg [PIX-1:0] line1 [0:MAX_IMG_W-1];
    reg [PIX-1:0] line2 [0:MAX_IMG_W-1];

    // ventana 3x3 (row-major): w0 w1 w2 / w3 w4 w5 / w6 w7 w8
    reg [PIX-1:0] w0,w1,w2,w3,w4,w5,w6,w7,w8;

    reg [$clog2(MAX_IMG_W)-1:0] col;
    reg [15:0]              row;

    wire [PIX-1:0] top = line2[col];      // vecino fila-2
    wire [PIX-1:0] mid = line1[col];      // vecino fila-1
    wire [PIX-1:0] bot = px_i;            // pixel actual

    wire [PIX-1:0] mag_int;
    assign mag_o  = mag_int;

    sobel_compass_core #(.PIX(PIX)) u_core (
        .window_i({w8,w7,w6,w5,w4,w3,w2,w1,w0}),
        .mag_o(mags8_o), .compass_o(mag_int), .dir_o(dir_o)
    );

    integer i;
    always @(posedge clk_i or negedge nreset_i) begin
        if (!nreset_i) begin
            col <= 0; row <= 0; out_valid_o <= 1'b0;
            w0<=0;w1<=0;w2<=0;w3<=0;w4<=0;w5<=0;w6<=0;w7<=0;w8<=0;
        end else begin
            out_valid_o <= 1'b0;
            if (px_valid_i) begin
                // desplazar columnas de la ventana e insertar columna derecha (top,mid,bot)
                w0<=w1; w1<=w2; w2<=top;
                w3<=w4; w4<=w5; w5<=mid;
                w6<=w7; w7<=w8; w8<=bot;
                // actualizar line buffers en esta columna
                line2[col] <= line1[col];
                line1[col] <= bot;
                // salida valida solo en interior (ventana 3x3 completa)
                if (row >= 2 && col >= 2) out_valid_o <= 1'b1;
                // contadores raster
                if (col == img_w_i-1) begin col <= 0; row <= row + 1; end
                else col <= col + 1;
            end
        end
    end
endmodule
`default_nettype wire
