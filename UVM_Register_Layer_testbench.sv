// First Steps with UVM - Register Layer

`include "uvm_macros.svh"

package my_pkg;

  import uvm_pkg::*;
  
  class my_reg extends uvm_reg;//定义一个单个寄存器的模型类
    `uvm_object_utils(my_reg)//这是 UVM 的宏（系统自带），作用是将 my_reg 注册进 UVM factory，必须写，否则 type_id::create() 会失败。
    // An 8-bit register containing a single 8-bit field
    rand uvm_reg_field f1;// 定义一个寄存器字段 f1，类型为 uvm_reg_field。uvm_reg_field：系统自带的类

    function new (string name = "");// 构造函数，name 是寄存器的名称
      super.new(name, 8, UVM_NO_COVERAGE);// 调用父类构造函数，8 是寄存器的位宽，UVM_NO_COVERAGE 表示不收集覆盖率
    endfunction
    
    function void build;                     // 构建寄存器
      f1 = uvm_reg_field::type_id::create("f1");// 通过 UVM factory 创建 uvm_reg_field 对象，名字叫 "f1"。系统函数 type_id::create() 是 uvm_object 类的标准创建方式。
      f1.configure(this, 8, 0, "RW", 0, 0, 1, 1, 0);// 调用系统自带的 configure() 方法来配置这个字段的属性。
                // reg, bitwidth, lsb, access, volatile, reselVal, hasReset, isRand, fieldAccess
    endfunction

  endclass


  class my_reg_model extends uvm_reg_block;//定义一个寄存器组或寄存器映射模型
    `uvm_object_utils(my_reg_model)//注册 my_reg_model 类到 UVM factory，用于 type_id::create() 动态构造
    
    // A register model containing two registers
    
    rand my_reg r0;//定义了两个字段 r0 和 r1，它们都是 my_reg 类型
    rand my_reg r1;
    
    function new (string name = "");// 构造函数，name 是寄存器组的名称
      super.new(name, build_coverage(UVM_NO_COVERAGE));
    endfunction

    function void build;
      r0 = my_reg::type_id::create("r0");//创建一个 r0 实例。type_id::create()：调用 UVM 工厂创建实例
      r0.build();// 调用 r0 的 build()，构建字段 f1
      r0.configure(this);// 绑定所属 block（即 my_reg_model）
      r0.add_hdl_path_slice("r0", 0, 8);//指定 HDL 路径映射，会查找 RTL 中名为 "r0" 的信号，然后访问它的 第 0 位起、8 位宽。

      r1 = my_reg::type_id::create("r1");//创建一个 r1 实例
      r1.build();// 调用 r1 的 build()，构建字段 f1
      r1.configure(this);// 绑定所属 block（即 my_reg_model）
      r1.add_hdl_path_slice("r1", 0, 8);      //指定 HDL 路径映射

      default_map = create_map("my_map", 0, 2, UVM_LITTLE_ENDIAN); // 创建一个寄存器映射，名字为 "my_map"，起始地址 0，大小 2 字节，字节序为小端
      default_map.add_reg(r0, 0, "RW");  // 将 r0 添加到默认映射，地址偏移 0，访问权限为读写
      default_map.add_reg(r1, 1, "RW");  // 将 r1 添加到默认映射，地址偏移 1，访问权限为读写
      
      lock_model();// 锁定寄存器模型，防止进一步修改
    endfunction

  endclass
  

  class my_transaction extends uvm_sequence_item;//定义一个事务类，用于在序列中传递数据
  
    `uvm_object_utils(my_transaction)//注册 my_transaction 类到 UVM factory，用于 type_id::create()
  
    rand bit cmd;// cmd = 1 表示写操作，cmd = 0 表示读操作
    rand int addr;// addr 是寄存器地址
    rand int data;// data 是寄存器数据
  
    constraint c_addr { addr >= 0; addr < 256; }// addr 必须在 0 到 255 之间
    constraint c_data { data >= 0; data < 256; }// data 必须在 0 到 255 之间
    
    function new (string name = "");// 构造函数，name 是事务的名称
      super.new(name);
    endfunction
    
    function string convert2string;// 将事务转换为字符串，便于调试输出
      return $sformatf("cmd=%b, addr=%0d, data=%0d", cmd, addr, data);// 返回格式化字符串
    endfunction

    function void do_copy(uvm_object rhs);// 复制函数，将 rhs 的内容复制到当前事务
      my_transaction tx;//定义一个变量 tx，类型是 my_transaction
      $cast(tx, rhs);// 将传入的父类指针 rhs 转换为 my_transaction 类型
      cmd  = tx.cmd;// 将 tx 的 cmd 复制到当前事务，这三句就是把 rhs 对象里的数据（被转换为 tx 后）赋值到当前对象（this）
      addr = tx.addr;// 将 tx 的 addr 复制到当前事务
      data = tx.data;
    endfunction
    
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);//
      my_transaction tx;//定义一个变量 tx，类型是 my_transaction
      bit status = 1;//定义一个 bit 类型变量 status，初值为 1
      $cast(tx, rhs);
      status &= (cmd  == tx.cmd);// 检查 cmd 是否相等，如果有任何字段不相等，status 就变为 0
      status &= (addr == tx.addr);
      status &= (data == tx.data);
      return status;
    endfunction

  endclass: my_transaction


  class my_adapter extends uvm_reg_adapter;//定义一个适配器类，用于将寄存器模型与序列连接起来
    `uvm_object_utils(my_adapter)
    
    // The adapter to connect the register model to the sequencer
    
    function new (string name = "");
      super.new(name);
    endfunction
 
    function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);//reg2bus：函数名，rw 是输入参数，类型是 uvm_reg_bus_op，const ref 表示按引用传递且不能在函数中修改
      my_transaction tx;
      tx = my_transaction::type_id::create("tx");//动态创建一个 my_transaction 实例；"tx" 是实例的名字
      tx.cmd = (rw.kind == UVM_WRITE);//rw.kind 是 uvm_reg_bus_op 结构中的字段，表示读或写。判断 rw 是不是写操作，是 → tx.cmd = 1；不是 → tx.cmd = 0
      tx.addr = rw.addr;// 将 rw 的地址赋值给 tx 的 addr 字段
      if (tx.cmd)// 如果是写操作，tx.cmd 是 1 就代表写操作
        tx.data = rw.data;// 将 rw 的数据赋值给 tx 的 data 字段
      return tx;
    endfunction
    
    function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);//bus2reg：函数名，bus_item 是输入参数，类型是 uvm_sequence_item，rw 是输出参数，类型是 uvm_reg_bus_op
      my_transaction tx;
      assert( $cast(tx, bus_item) )// 将 bus_item 转换为 my_transaction 类型，如果转换失败则报错
        else `uvm_fatal("", "A bad thing has just happened in my_adapter")// 报告一个致命错误

      if (tx.addr < 2) // 检查地址是否在有效范围内（0 或 1）这里人为规定：只有地址小于2的事务才被认为是“有效的
      begin     
        rw.kind = tx.cmd ? UVM_WRITE : UVM_READ;//如果 tx.cmd 为 1，表示写操作，赋值为 UVM_WRITE；否则为 UVM_READ
        rw.addr = tx.addr;// 将 tx 的地址赋值给 rw 的地址字段
        rw.data = tx.data;  // 如果是写操作，rw.data 就是 tx 的数据
        rw.status = UVM_IS_OK;// 设置 rw 的状态为 UVM_IS_OK，表示操作成功
      end
      else
        rw.status = UVM_NOT_OK;
    endfunction
      
  endclass
  
  
  class my_reg_seq extends uvm_sequence;//定义一个名为 my_reg_seq 的寄存器访问序列类，继承自 uvm_sequence。

    `uvm_object_utils(my_reg_seq)

    function new (string name = "");
      super.new(name);
    endfunction
    
    my_reg_model regmodel;// 定义一个 my_reg_model 类型的变量 regmodel，用于访问寄存器模型

    task body;
      uvm_status_e   status;// 定义一个 uvm_status_e 类型的变量 status，用于存储操作状态
      uvm_reg_data_t incoming;// 定义一个 uvm_reg_data_t 类型的变量 incoming，用于存储寄存器数据
      
      if (starting_phase != null)// 检查 starting_phase 是否为 null，如果不是，则表示当前序列在一个特定的阶段运行
        starting_phase.raise_objection(this);// 提出一个异议，表示当前序列正在运行中

      regmodel.r0.write(status, .value(111), .parent(this));// 调用寄存器模型的 r0 寄存器的 write 方法，将 111 写入 regmodel.r0 寄存器
      assert( status == UVM_IS_OK );// 检查写操作是否成功，如果 status 不等于 UVM_IS_OK，则断言失败

      regmodel.r1.write(status, .value(222), .parent(this));// 调用寄存器模型的 r1 寄存器的 write 方法，将 222 写入 regmodel.r1 寄存器
      assert( status == UVM_IS_OK );// 检查写操作是否成功，如果 status 不等于 UVM_IS_OK，则断言失败

      regmodel.r0.read(status, .value(incoming), .parent(this));// 调用寄存器模型的 r0 寄存器的 read 方法，将寄存器值读取到 incoming 变量中
      assert( status == UVM_IS_OK );// 检查读操作是否成功，如果 status 不等于 UVM_IS_OK，则断言失败
      assert( incoming == 111 )// 检查读取的值是否等于 111，如果不等于则断言失败
        else `uvm_warning("", $sformatf("incoming = %4h, expected = 111", incoming))// 输出警告信息，显示实际值和期望值

      regmodel.r1.read(status, .value(incoming), .parent(this));// 调用寄存器模型的 r1 寄存器的 read 方法，将寄存器值读取到 incoming 变量中
      assert( status == UVM_IS_OK );// 检查读操作是否成功，如果 status 不等于 UVM_IS_OK，则断言失败
      assert( incoming == 222 )// 检查读取的值是否等于 222，如果不等于则断言失败
        else `uvm_warning("", $sformatf("incoming = %4h, expected = 222", incoming))// 输出警告信息，显示实际值和期望值

      if (starting_phase != null)// 检查 starting_phase 是否为 null，如果不是，则表示当前序列在一个特定的阶段运行
        starting_phase.drop_objection(this);// 释放异议，表示当前序列已完成运行
    endtask
    
  endclass
  
  
  class my_driver extends uvm_driver #(my_transaction);//定义一个驱动类 my_driver，继承自 uvm_driver，并指定事务类型为 my_transaction。
  
    `uvm_component_utils(my_driver)

    virtual dut_if dut_vi;// 定义一个虚拟接口 dut_vi，用于与 DUT 进行通信

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);//
      // Get interface reference from config database
      if( !uvm_config_db #(virtual dut_if)::get(this, "", "dut_if", dut_vi) )// // 从配置数据库中获取名为 "dut_if" 的 virtual dut_if 类型的接口，并赋值给 dut_vi
        `uvm_error("", "uvm_config_db::get failed")
    endfunction 
   
    task run_phase(uvm_phase phase);// 定义一个任务 run_phase，用于驱动 DUT 的操作
      forever// 在 run_phase 中循环执行以下操作
      begin
        seq_item_port.get_next_item(req);//从 sequencer 获取下一个事务对象，保存在 req 变量中。req 的类型是 my_transaction

        // Wiggle pins of DUT
        dut_vi.en    <= 1;// 设置 DUT 接口的使能信号为 1，表示开始操作
        dut_vi.cmd   <= req.cmd;// 将事务的 cmd 字段赋值给 DUT 接口的 cmd 信号
        dut_vi.addr  <= req.addr;// 将事务的 addr 字段赋值给 DUT 接口的 addr 信号
        if (req.cmd)// 如果是写操作
          dut_vi.wdata <= req.data;// 将事务的 data 字段赋值给 DUT 接口的 wdata 信号
          
        @(posedge dut_vi.clock);// 等待 DUT 接口的时钟上升沿，确保数据稳定
        
        if (req.cmd == 0)// 如果是读操作
        begin
          @(posedge dut_vi.clock);//dut_vi 是 virtual dut_if 类型变量，clock 是 interface dut_if 中定义的时钟信号
          req.data = dut_vi.rdata;// 将 DUT 接口的 rdata 信号赋值给事务的 data 字段
        end
        
        seq_item_port.item_done();
      end
    endtask

  endclass: my_driver
  
  
  typedef uvm_sequencer #(my_transaction) my_sequencer;//简化命名，等同于你之前用的 uvm_sequencer 对应 transaction 的封装


  class my_env extends uvm_env;//定义一个环境类 my_env，继承自 uvm_env，用于组织和管理测试组件。

    `uvm_component_utils(my_env)//注册 my_env 类到 UVM factory，用于 type_id::create()
    
    my_reg_model  regmodel;  // 定义一个 my_reg_model 类型的变量 regmodel，用于访问寄存器模型
    my_adapter    m_adapter;// 定义一个 my_adapter 类型的变量 m_adapter，用于连接寄存器模型和序列
    my_sequencer m_seqr;// 定义一个 my_sequencer 类型的变量 m_seqr，用于生成事务序列
    my_driver    m_driv;// 定义一个 my_driver 类型的变量 m_driv，用于驱动 DUT 的操作
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
 
    function void build_phase(uvm_phase phase);// 定义 build_phase 方法，用于构建环境组件
    
      // Instantiate the register model and adapter
      regmodel = my_reg_model::type_id::create("regmodel", this);// 创建一个 my_reg_model 实例，名字为 "regmodel"，父组件为当前环境（this）
      regmodel.build();// 调用 regmodel 的 build() 方法，构建寄存器模型
      
      m_adapter = my_adapter::type_id::create("m_adapter",, get_full_name());// 创建一个 my_adapter 实例，名字为 "m_adapter"，父组件为当前环境的全名
      
      m_seqr = my_sequencer::type_id::create("m_seqr", this);// 创建一个 my_sequencer 实例，名字为 "m_seqr"，父组件为当前环境（this）
      m_driv = my_driver   ::type_id::create("m_driv", this);// 创建一个 my_driver 实例，名字为 "m_driv"，父组件为当前环境（this）
    endfunction
    
    function void connect_phase(uvm_phase phase);//定义 connect_phase 方法
      regmodel.default_map.set_sequencer( .sequencer(m_seqr), .adapter(m_adapter) );//把 regmodel（一般是 UVM reg block/模型）的 default_map（默认映射）所需要的 sequencer 和 adapter 进行绑定。
      regmodel.default_map.set_base_addr(0);// 设置默认映射的基地址为 0
      regmodel.add_hdl_path("top.dut1");// 将寄存器模型与 DUT 的顶层模块绑定，路径为 "top.dut1"

      m_driv.seq_item_port.connect( m_seqr.seq_item_export );
    endfunction
    
  endclass: my_env
  
  
  class my_test extends uvm_test;//定义一个测试类，用于启动测试环境和寄存器序列
  
    `uvm_component_utils(my_test)
    
    my_env m_env;
    
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
      m_env = my_env::type_id::create("m_env", this);// 创建一个 my_env 实例，名字为 "m_env"，父组件为当前测试（this）
    endfunction
    
    task run_phase(uvm_phase phase);
      my_reg_seq seq;// 定义一个 my_reg_seq 类型的变量 seq，用于生成寄存器访问序列
      seq = my_reg_seq::type_id::create("seq");// 创建一个 my_reg_seq 实例，名字为 "seq"
      if ( !seq.randomize() )// 调用 randomize() 方法随机化 seq 的属性，如果失败则报错
        `uvm_error("", "Randomize failed")//如果随机化失败（返回0），则用 UVM 的 uvm_error 宏打印报错消息。
      seq.regmodel = m_env.regmodel;   //给 seq 这个 sequence 对象的 regmodel 句柄赋值
      seq.starting_phase = phase;// 将当前运行阶段赋值给 seq 的 starting_phase 字段
      seq.start( m_env.m_seqr );// 启动 seq，传入 m_env.m_seqr 作为 sequencer
    endtask
     
  endclass: my_test
  
  
endpackage: my_pkg


module top;

  import uvm_pkg::*;// 导入 UVM 包
  import my_pkg::*;// 导入自定义包 my_pkg
  
  dut_if dut_if1 ();// 创建一个 DUT 接口实例 dut_if1
  
  dut    dut1 ( .dif(dut_if1) );// 创建一个 DUT 实例 dut1，并将 dut_if1 连接到它的 dif 接口。.dif（点dif）其实就是DUT模块端口名的简写

  // Clock generator
  initial
  begin
    dut_if1.clock = 0;// 初始化时钟信号为 0
    forever #5 dut_if1.clock = ~dut_if1.clock;
  end

  initial
  begin
    uvm_config_db #(virtual dut_if)::set(null, "*", "dut_if", dut_if1);// 让所有UVM组件都能通过" dut_if "这个名字拿到虚拟接口dut_if1，以便后续驱动和监控DUT信号。
    
    uvm_top.finish_on_completion = 1;// 设置 UVM 顶层的 finish_on_completion 为 1，表示测试完成后自动结束仿真
    
    run_test("my_test");// 启动测试，传入测试类 my_test 的名称。my_test 是我们之前定义的测试类，它会创建环境、寄存器模型和序列等。
  end

endmodule: top
