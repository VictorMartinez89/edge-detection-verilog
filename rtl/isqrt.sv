// =============================================================================
// isqrt.sv  -- raiz cuadrada ENTERA combinacional (algoritmo no-restaurador).
//   y = floor(sqrt(x)).  Para la magnitud Canny real sqrt(Gx^2+Gy^2) o
//   para tu combinacion sqrt(G_low+G_high).  W debe ser par; salida W/2 bits.
//   Es la alternativa "cara pero posible" a |Gx|+|Gy| cuando quieres la
//   magnitud euclidiana exacta en hardware (sin multiplicador, solo shift/sumas).
// =============================================================================
`default_nettype none
module isqrt #(parameter integer W=16)(
    input  wire [W-1:0]    x_i,
    output wire [W/2-1:0]  y_o
);
    function automatic [W/2-1:0] root_f(input [W-1:0] num);
        integer i;
        reg [W-1:0]   rem, nv, test;
        reg [W/2-1:0] root;
        begin
            rem = 0; root = 0; nv = num;
            for (i=0; i<W/2; i=i+1) begin
                root = root << 1;
                rem  = (rem << 2) | ((nv >> (W-2)) & 2'b11);
                nv   = nv << 2;
                test = ({ {(W-W/2){1'b0}}, root } << 1) | { {(W-1){1'b0}}, 1'b1 };
                if (rem >= test) begin
                    rem  = rem - test;
                    root = root | 1'b1;
                end
            end
            root_f = root;
        end
    endfunction
    assign y_o = root_f(x_i);
endmodule
`default_nettype wire
