// in a shared package so the top module FSM and top module use the same type
package mem_pkg;
    typedef enum logic [1:0] {
        MEM_NONE = 2'd0,
        MEM_UART = 2'd1,
        MEM_COMPUTE = 2'd2
    } mem_owner_t;
endpackage
