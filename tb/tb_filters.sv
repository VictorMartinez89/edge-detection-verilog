`default_nettype none
`timescale 1ns/1ps
module tb_filters;
  integer errors = 0;
  task check(input [255:0] name, input integer got, input integer exp);
    begin
      if (got !== exp) begin $display("  FAIL %0s: got=%0d exp=%0d", name, got, exp); errors=errors+1; end
      else                 $display("  ok   %0s = %0d", name, got);
    end
  endtask

  // ---- pack a 3x3 window (8b) row-major ----
  function [71:0] win3(input [7:0] a,b,c,d,e,f,g,h,i);
    win3 = {i,h,g,f,e,d,c,b,a};   // [8*0+:8]=a ... [8*8+:8]=i
  endfunction

  // ===== Sobel compass =====
  reg  [71:0] w;
  wire [63:0] mag; wire [7:0] comp; wire [2:0] dir;
  sobel_compass_core u_scc(.window_i(w), .mag_o(mag), .compass_o(comp), .dir_o(dir));

  // ===== Gaussian =====
  reg [9*8-1:0]  w3; reg [25*8-1:0] w5; reg [49*8-1:0] w7;
  wire [7:0] g3,g5,g7;
  gaussian3x3 u3(.win_i(w3), .gray_o(g3));
  gaussian5x5 u5(.win_i(w5), .gray_o(g5));
  gaussian7x7 u7(.win_i(w7), .gray_o(g7));

  // ===== isqrt =====
  reg [15:0] sx; wire [7:0] sy;
  isqrt #(.W(16)) uq(.x_i(sx), .y_o(sy));

  // ===== canny threshold =====
  reg [11:0] mg, lo, hi; wire [11:0] gl, gh; wire [1:0] cl; wire [6:0] cb;
  canny_grad_threshold_core #(.MAGW(12)) uc(.mag_i(mg),.low_i(lo),.high_i(hi),
       .g_low_o(gl),.g_high_o(gh),.class_o(cl),.combo_o(cb));

  integer k;
  initial begin
    $display("== Sobel compass (ventana 10..90) ==");
    w = win3(8'd10,8'd20,8'd30,8'd40,8'd50,8'd60,8'd70,8'd80,8'd90);
    #1;
    check("|N| ", mag[8*0+:8], 240);
    check("|E| ", mag[8*2+:8], 80);
    check("|SE|", mag[8*3+:8], 120);
    check("compass_max", comp, 240);
    check("dir(N=0)", dir, 0);

    $display("== Gaussian (ventana uniforme=100 -> 100) ==");
    for (k=0;k<9;k=k+1)  w3[8*k+:8]=8'd100;
    for (k=0;k<25;k=k+1) w5[8*k+:8]=8'd100;
    for (k=0;k<49;k=k+1) w7[8*k+:8]=8'd100;
    #1; check("g3", g3, 100); check("g5", g5, 100); check("g7", g7, 100);

    $display("== isqrt ==");
    sx=16'd144;  #1; check("sqrt(144)",  sy, 12);
    sx=16'd255;  #1; check("sqrt(255)",  sy, 15);
    sx=16'd1000; #1; check("sqrt(1000)", sy, 31);
    sx=16'd65535;#1; check("sqrt(65535)",sy, 255);

    $display("== Canny doble umbral + combo sqrt(G_low+G_high) ==");
    mg=12'd100; lo=12'd50; hi=12'd120; #1;
    check("weak g_low",gl,100); check("weak g_high",gh,0); check("weak class",cl,1); check("weak combo sqrt(100)",cb,10);
    mg=12'd200; lo=12'd50; hi=12'd120; #1;
    check("strong g_high",gh,200); check("strong class",cl,2); check("strong combo sqrt(400)",cb,20);

    if (errors==0) $display("\nALL TESTS PASSED"); else $display("\n%0d FAILURES", errors);
    $finish;
  end
endmodule
`default_nettype wire
