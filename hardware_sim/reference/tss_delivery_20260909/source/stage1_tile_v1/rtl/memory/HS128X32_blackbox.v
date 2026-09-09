`timescale 1ns/1ps

(* black_box *)
module HS128X32 (
    output [31:0] Q,
    input         CLK,
    input         CEN,
    input         WEN,
    input  [6:0]  A,
    input  [31:0] D,
    input  [2:0]  EMA,
    input  [1:0]  EMAW,
    input         EMAS,
    input         RET1N
);
endmodule
