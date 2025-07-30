`include "uvm_macros.svh"

interface dut_if;//定义了一个名为 dut_if 的 SystemVerilog interface，相当于“信号的打包容器

  // Simple synchronous bus interface
  logic clock, reset;// 定义时钟和复位信号
  logic en;// 使能信号
  logic cmd;// 命令信号，可能用于读写操作
  logic [7:0] addr;// 地址信号，用于指定寄存器或内存位置
  logic [7:0] wdata;// 写数据信号，用于传输要写入的值
  logic [7:0] rdata;// 读数据信号，用于接收从寄存器或内存读取的值

endinterface


module dut(dut_if dif);// 定义一个名为 dut 的模块，输入是一个名为 dif 的 dut_if 接口实例

  import uvm_pkg::*;

  // Two memory-mapped registers at addresses 0 and 1
  logic [7:0] r0;// 定义寄存器 r0，用于存储地址 0 的数据
  logic [7:0] r1;// 定义寄存器 r1，用于存储地址 1 的数据
  
  always @(posedge dif.clock)// 当时钟上升沿到来时触发以下逻辑
  begin
 
    if (dif.en)// 如果使能信号为高
    begin
      logic [7:0] value;// 定义一个临时变量 value，用于存储要返回的数据
      
      if (dif.cmd == 1 )//如果命令信号为1，且地址为0或1，就把wdata写进r0/r1。
        if (dif.addr == 0)// 如果地址为 0
          r0 <= dif.wdata;// 将写入数据 wdata 存储到寄存器 r0
        else if (dif.addr == 1)// 如果地址为 1
          r1 <= dif.wdata;// 将写入数据 wdata 存储到寄存器 r1
        
      if (dif.cmd == 0)//如果命令信号为0，且地址为0或1，就读出r0/r1给临时变量value，否则给一个随机数。
        if (dif.addr == 0)// 如果地址为 0
          value = r0;// 将寄存器 r0 的值赋给临时变量 value
        else if (dif.addr == 1)// 如果地址为 1
          value = r1;// 将寄存器 r1 的值赋给临时变量 value
        else
          value = $random;// 如果地址不是 0 或 1，则将 value 设置为一个随机数

      if (dif.cmd == 1)// 如果命令信号为 1，表示写操作
        `uvm_info("", $sformatf("DUT received cmd=%b, addr=%d, wdata=%d",// 写操作时，打印收到的写命令、地址和写数据（wdata）
                            dif.cmd, dif.addr, dif.wdata), UVM_MEDIUM)// 读操作时，打印收到的读命令、地址和读出的数据（rdata）
      else
        `uvm_info("", $sformatf("DUT received cmd=%b, addr=%d, rdata=%d",
                            dif.cmd, dif.addr, value), UVM_MEDIUM)
      dif.rdata <= value;// 将临时变量 value 的值赋给接口的读数信号 rdata
    end
  end
  
endmodule
