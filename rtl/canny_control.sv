// =============================================================================
// canny_control.sv  -- Canny en STREAMING: ventana deslizante 7x7 (6 line buffers)
//   que alimenta canny_full_core (gradiente + NMS + doble umbral + histeresis 1-salto).
//   Recibe gris suavizado en raster; entrega edge_o + class_o en pixeles interiores
//   (row>=6 && col>=6; centro = (row-3,col-3), borde de 3 px).
//   Mismo patron de line buffers que sobel_compass_control, extendido a 7 filas.
// =============================================================================
`default_nettype none
module canny_control #(
    parameter integer PIX   = 8,
    parameter integer MAGW  = 12,
    parameter integer MAX_IMG_W = 1024
)(
    input  wire           clk_i,
    input  wire           nreset_i,
    input  wire [15:0]    img_w_i,
    input  wire           px_valid_i,
    input  wire [PIX-1:0] px_i,
    input  wire [MAGW-1:0] low_i, high_i,
    output reg            out_valid_o,
    output wire           edge_o,
    output wire [1:0]     class_o
);
    reg [PIX-1:0] lb1[0:MAX_IMG_W-1], lb2[0:MAX_IMG_W-1], lb3[0:MAX_IMG_W-1],
                  lb4[0:MAX_IMG_W-1], lb5[0:MAX_IMG_W-1], lb6[0:MAX_IMG_W-1];
    reg [PIX-1:0] win [0:6][0:6];
    reg [$clog2(MAX_IMG_W)-1:0] col;
    reg [15:0] row;

    // ventana -> vector empacado para el core
    wire [49*PIX-1:0] gwin;
    genvar r,c;
    generate for (r=0;r<7;r=r+1) for (c=0;c<7;c=c+1)
        assign gwin[PIX*(r*7+c) +: PIX] = win[r][c];
    endgenerate

    canny_full_core #(.PIX(PIX), .MAGW(MAGW)) u_core
        (.gwin_i(gwin), .low_i(low_i), .high_i(high_i), .edge_o(edge_o), .class_o(class_o));

    // columna vertical nueva (rows row-6..row en la columna col)
    wire [PIX-1:0] nc0=lb6[col], nc1=lb5[col], nc2=lb4[col],
                   nc3=lb3[col], nc4=lb2[col], nc5=lb1[col], nc6=px_i;
    integer i;
    always @(posedge clk_i or negedge nreset_i) begin
        if (!nreset_i) begin
            col<=0; row<=0; out_valid_o<=1'b0;
            for (i=0;i<7;i=i+1) begin
                win[i][0]<=0;win[i][1]<=0;win[i][2]<=0;win[i][3]<=0;
                win[i][4]<=0;win[i][5]<=0;win[i][6]<=0;
            end
        end else begin
            out_valid_o<=1'b0;
            if (px_valid_i) begin
                // desplazar columnas a la izquierda e insertar columna derecha
                win[0][0]<=win[0][1];win[0][1]<=win[0][2];win[0][2]<=win[0][3];win[0][3]<=win[0][4];win[0][4]<=win[0][5];win[0][5]<=win[0][6];win[0][6]<=nc0;
                win[1][0]<=win[1][1];win[1][1]<=win[1][2];win[1][2]<=win[1][3];win[1][3]<=win[1][4];win[1][4]<=win[1][5];win[1][5]<=win[1][6];win[1][6]<=nc1;
                win[2][0]<=win[2][1];win[2][1]<=win[2][2];win[2][2]<=win[2][3];win[2][3]<=win[2][4];win[2][4]<=win[2][5];win[2][5]<=win[2][6];win[2][6]<=nc2;
                win[3][0]<=win[3][1];win[3][1]<=win[3][2];win[3][2]<=win[3][3];win[3][3]<=win[3][4];win[3][4]<=win[3][5];win[3][5]<=win[3][6];win[3][6]<=nc3;
                win[4][0]<=win[4][1];win[4][1]<=win[4][2];win[4][2]<=win[4][3];win[4][3]<=win[4][4];win[4][4]<=win[4][5];win[4][5]<=win[4][6];win[4][6]<=nc4;
                win[5][0]<=win[5][1];win[5][1]<=win[5][2];win[5][2]<=win[5][3];win[5][3]<=win[5][4];win[5][4]<=win[5][5];win[5][5]<=win[5][6];win[5][6]<=nc5;
                win[6][0]<=win[6][1];win[6][1]<=win[6][2];win[6][2]<=win[6][3];win[6][3]<=win[6][4];win[6][4]<=win[6][5];win[6][5]<=win[6][6];win[6][6]<=nc6;
                // actualizar line buffers en esta columna
                lb6[col]<=lb5[col]; lb5[col]<=lb4[col]; lb4[col]<=lb3[col];
                lb3[col]<=lb2[col]; lb2[col]<=lb1[col]; lb1[col]<=px_i;
                if (row>=6 && col>=6) out_valid_o<=1'b1;
                if (col==img_w_i-1) begin col<=0; row<=row+1; end
                else col<=col+1;
            end
        end
    end
endmodule
`default_nettype wire
