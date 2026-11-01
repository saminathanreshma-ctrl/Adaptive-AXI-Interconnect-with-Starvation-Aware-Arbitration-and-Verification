module tb_memory_readback;

    reg clk, rst;
    reg [1:0] req;
    reg mode, done;

    reg [31:0] m0_addr, m1_addr;
    reg m0_write, m1_write;
    reg [31:0] m0_wdata, m1_wdata;

    wire [1:0] grant;
    wire [31:0] rdata;
    wire ready, addr_valid;

    integer errors;
    integer wait_count;

    reg [1:0] first_rr_grant;
    reg [1:0] second_rr_grant;

    //========================================
    // DUT INSTANTIATION
    //========================================

    axi_interconnect_top DUT (
        .clk(clk),
        .rst(rst),
        .req(req),
        .mode(mode),
        .done(done),
        .m0_addr(m0_addr),
        .m0_write(m0_write),
        .m0_wdata(m0_wdata),
        .m1_addr(m1_addr),
        .m1_write(m1_write),
        .m1_wdata(m1_wdata),
        .grant(grant),
        .rdata(rdata),
        .ready(ready),
        .addr_valid(addr_valid)
    );

    //========================================
    // CLOCK GENERATION
    //========================================

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //========================================
    // FUNCTIONAL COVERAGE
    //========================================

    covergroup axi_functional_coverage @(posedge clk);

        cp_mode: coverpoint mode iff (!rst) {
            bins fixed_priority = {0};
            bins round_robin = {1};
        }

        cp_grant: coverpoint grant iff (!rst) {
            bins no_grant = {2'b00};
            bins master0 = {2'b01};
            bins master1 = {2'b10};
        }

        cp_slave: coverpoint {DUT.s1_select, DUT.s0_select}
            iff (!rst) {
            bins no_slave = {2'b00};
            bins slave0 = {2'b01};
            bins slave1 = {2'b10};
            bins both_slaves = {2'b11};
        }

        cp_m0_write: coverpoint m0_write
            iff (!rst && grant == 2'b01) {
            bins read_operation = {0};
            bins write_operation = {1};
        }

        cp_m1_write: coverpoint m1_write
            iff (!rst && grant == 2'b10) {
            bins read_operation = {0};
            bins write_operation = {1};
        }

        cp_starved0: coverpoint DUT.starved0 iff (!rst) {
            bins not_starved = {0};
            bins starved = {1};
        }

        cp_starved1: coverpoint DUT.starved1 iff (!rst) {
            bins not_starved = {0};
            bins starved = {1};
        }

        cp_address: coverpoint DUT.selected_addr
            iff (!rst && grant != 2'b00) {
            bins slave0_address =
                {[32'h00000000:32'h00000FFF]};

            bins slave1_address =
                {[32'h00001000:32'h00001FFF]};

            bins invalid_address =
                {[32'h00002000:32'hFFFFFFFF]};
        }

        cp_starvation_status:
            coverpoint {DUT.starved1, DUT.starved0}
            iff (!rst) {
            bins neither = {2'b00};
            bins m0_only = {2'b01};
            bins m1_only = {2'b10};
            bins both = {2'b11};
        }

        cp_operation: coverpoint
            ((grant == 2'b01) ? m0_write :
             (grant == 2'b10) ? m1_write : 1'b0)
            iff (!rst && grant != 2'b00) {
            bins read = {0};
            bins write = {1};
        }

        cx_mode_grant:
            cross cp_mode, cp_grant;

        cx_grant_slave:
            cross cp_grant, cp_slave;

        cx_grant_operation:
            cross cp_grant, cp_operation;

        cx_starvation_grant:
            cross cp_starvation_status, cp_grant;

        cx_slave_operation:
            cross cp_slave, cp_operation;

        option.per_instance = 1;

    endgroup

    axi_functional_coverage axi_cov = new();

    //========================================
    // ASSERTION 1: ONE-HOT GRANT
    //========================================

    property p_grant_onehot;
        @(posedge clk)
        disable iff (rst)
        !(grant[1] && grant[0]);
    endproperty

    assert property (p_grant_onehot)
    else begin
        $error("ASSERTION 1 FAILED: Both masters received grant");
        errors = errors + 1;
    end

    //========================================
    // ASSERTION 2: SELECTED SLAVE RESPONSE
    //========================================

    property p_selected_slave_ready;
        @(posedge clk)
        disable iff (rst)
        (DUT.s0_select || DUT.s1_select)
        |=> ready;
    endproperty

    assert property (p_selected_slave_ready)
    else begin
        $error("ASSERTION 2 FAILED: Selected slave did not respond");
        errors = errors + 1;
    end

    //========================================
    // ASSERTION 3: VALID MAPPED ADDRESS
    //========================================

    // Invalid addresses are intentionally tested in Test 8.
    // Therefore, only mapped addresses are checked here.

    property p_granted_address_valid;
        @(posedge clk)
        disable iff (rst)
        (
            grant != 2'b00 &&
            DUT.selected_addr <= 32'h00001FFF
        )
        |-> addr_valid;
    endproperty

    assert property (p_granted_address_valid)
    else begin
        $error("ASSERTION 3 FAILED: Valid mapped address rejected");
        errors = errors + 1;
    end

    //========================================
    // ASSERTION 4: READ DATA VALIDITY
    //========================================

    property p_read_data_valid;
        @(posedge clk)
        disable iff (rst)
        (
            ready &&
            (
                (grant == 2'b01 && !m0_write) ||
                (grant == 2'b10 && !m1_write)
            )
        )
        |-> !$isunknown(rdata);
    endproperty

    assert property (p_read_data_valid)
    else begin
        $error("ASSERTION 4 FAILED: Read data contains X or Z");
        errors = errors + 1;
    end

    //========================================
    // ASSERTION 5: GRANT STABILITY
    //========================================

    property p_grant_stability;
        @(posedge clk)
        disable iff (rst)
        (grant != 2'b00 && !done)
        |=> (done || $stable(grant));
    endproperty

    assert property (p_grant_stability)
    else begin
        $error("ASSERTION 5 FAILED: Grant changed before completion");
        errors = errors + 1;
    end

    //========================================
    // ASSERTION 6: ADDRESS STABILITY
    //========================================

    property p_address_stability;
        @(posedge clk)
        disable iff (rst)
        (grant != 2'b00 && !done)
        |=> (done || $stable(DUT.selected_addr));
    endproperty

    assert property (p_address_stability)
    else begin
        $error("ASSERTION 6 FAILED: Address changed before completion");
        errors = errors + 1;
    end

    //========================================
    // ASSERTION 7: WRITE DATA STABILITY
    //========================================

    property p_write_data_stability;
        @(posedge clk)
        disable iff (rst)
        (
            grant != 2'b00 &&
            !done &&
            (
                (grant == 2'b01 && m0_write) ||
                (grant == 2'b10 && m1_write)
            )
        )
        |=> (done || $stable(DUT.selected_wdata));
    endproperty

    assert property (p_write_data_stability)
    else begin
        $error("ASSERTION 7 FAILED: Write data changed");
        errors = errors + 1;
    end

    //========================================
    // ASSERTION 8: NO RESPONSE WITHOUT SELECTION
    //========================================

    property p_no_response_without_selection;
        @(posedge clk)
        disable iff (rst)
        !(DUT.s0_select || DUT.s1_select)
        |=> !ready;
    endproperty

    assert property (p_no_response_without_selection)
    else begin
        $error("ASSERTION 8 FAILED: Response without selection");
        errors = errors + 1;
    end

    //========================================
    // ASSERTION 9: STARVATION FLAG VALIDITY
    //========================================

    property p_starvation_flag_m0;
        @(posedge clk)
        disable iff (rst)
        DUT.starved0 |-> req[0];
    endproperty

    assert property (p_starvation_flag_m0)
    else begin
        $error("ASSERTION 9 FAILED: Invalid M0 starvation flag");
        errors = errors + 1;
    end

    property p_starvation_flag_m1;
        @(posedge clk)
        disable iff (rst)
        DUT.starved1 |-> req[1];
    endproperty

    assert property (p_starvation_flag_m1)
    else begin
        $error("ASSERTION 9 FAILED: Invalid M1 starvation flag");
        errors = errors + 1;
    end

    //========================================
    // ASSERTION 10: STARVATION PRIORITY
    //========================================

    property p_starvation_priority_m0;
        @(posedge clk)
        disable iff (rst)
        (
            done &&
            DUT.starved0 &&
            !DUT.starved1 &&
            req[0]
        )
        |-> ##[1:2] (grant == 2'b01);
    endproperty

    assert property (p_starvation_priority_m0)
    else begin
        $error("ASSERTION 10 FAILED: Starved M0 did not receive priority");
        errors = errors + 1;
    end

    property p_starvation_priority_m1;
        @(posedge clk)
        disable iff (rst)
        (
            done &&
            DUT.starved1 &&
            !DUT.starved0 &&
            req[1]
        )
        |-> ##[1:2] (grant == 2'b10);
    endproperty

    assert property (p_starvation_priority_m1)
    else begin
        $error("ASSERTION 10 FAILED: Starved M1 did not receive priority");
        errors = errors + 1;
    end

    //========================================
    // TASK: MEMORY TRANSACTION
    //========================================

    task memory_transaction;

        input integer master;
        input reg write_enable;
        input [31:0] address;
        input [31:0] write_data;
        input [31:0] expected_data;

        begin
            @(negedge clk);

            done = 0;

            if (master == 0) begin
                req = 2'b01;
                m0_addr = address;
                m0_write = write_enable;
                m0_wdata = write_data;
            end
            else begin
                req = 2'b10;
                m1_addr = address;
                m1_write = write_enable;
                m1_wdata = write_data;
            end

            wait (grant == (master == 0 ? 2'b01 : 2'b10));

            @(posedge clk);
            #1;

            if (addr_valid !== 1'b1) begin
                $display("ERROR: Invalid address");
                errors = errors + 1;
            end

            if (ready !== 1'b1) begin
                $display("ERROR: Memory not ready");
                errors = errors + 1;
            end
            else begin
                if (write_enable) begin
                    $display(
                        "M%0d WRITE: Address=%h Data=%h",
                        master, address, write_data
                    );
                    $display("WRITE COMPLETED");
                end
                else begin
                    $display(
                        "M%0d READ: Address=%h Data=%h",
                        master, address, rdata
                    );

                    if (rdata === expected_data) begin
                        $display(
                            "READ BACK PASSED: Expected=%h Actual=%h",
                            expected_data, rdata
                        );
                    end
                    else begin
                        $display(
                            "READ BACK FAILED: Expected=%h Actual=%h",
                            expected_data, rdata
                        );
                        errors = errors + 1;
                    end
                end
            end

            @(negedge clk);
            req = 2'b00;
            done = 1;

            @(posedge clk);
            #1;
            done = 0;

            @(posedge clk);
            #1;
        end

    endtask

    //========================================
    // MAIN TEST SEQUENCE
    //========================================

    initial begin

        errors = 0;
        wait_count = 0;

        first_rr_grant = 2'b00;
        second_rr_grant = 2'b00;

        rst = 1;
        req = 0;
        mode = 0;
        done = 0;

        m0_addr = 0;
        m1_addr = 0;
        m0_write = 0;
        m1_write = 0;
        m0_wdata = 0;
        m1_wdata = 0;

        $display("======================================");
        $display(" ADAPTIVE AXI INTERCONNECT VERIFICATION");
        $display("======================================");

        $display("ASSERTION 1: ONE-HOT GRANT");
        $display("ASSERTION 2: SLAVE RESPONSE");
        $display("ASSERTION 3: ADDRESS VALIDITY");
        $display("ASSERTION 4: READ DATA VALIDITY");
        $display("ASSERTION 5: GRANT STABILITY");
        $display("ASSERTION 6: ADDRESS STABILITY");
        $display("ASSERTION 7: WRITE DATA STABILITY");
        $display("ASSERTION 8: NO RESPONSE WITHOUT SELECTION");
        $display("ASSERTION 9: STARVATION FLAG VALIDITY");
        $display("ASSERTION 10: STARVATION PRIORITY");

        $display("FUNCTIONAL COVERAGE: 10 COVERPOINTS + 5 CROSSES");
        $display("======================================");

        repeat (2) @(negedge clk);
        rst = 0;

        //========================================
        // TEST 1: M0 MEMORY WRITE
        //========================================

        $display("\nTEST 1: M0 MEMORY WRITE");

        memory_transaction(
            0, 1'b1,
            32'h00000005,
            32'h12345678,
            32'h12345678
        );

        //========================================
        // TEST 2: M0 MEMORY READ
        //========================================

        $display("\nTEST 2: M0 MEMORY READ");

        memory_transaction(
            0, 1'b0,
            32'h00000005,
            32'h00000000,
            32'h12345678
        );

        //========================================
        // TEST 3: M1 MEMORY WRITE
        //========================================

        $display("\nTEST 3: M1 MEMORY WRITE");

        memory_transaction(
            1, 1'b1,
            32'h0000100A,
            32'hABCDEF12,
            32'hABCDEF12
        );

        //========================================
        // TEST 4: M1 MEMORY READ
        //========================================

        $display("\nTEST 4: M1 MEMORY READ");

        memory_transaction(
            1, 1'b0,
            32'h0000100A,
            32'h00000000,
            32'hABCDEF12
        );

        //========================================
        // TEST 5: ROUND-ROBIN ARBITRATION
        //========================================

        $display("\nTEST 5: ROUND-ROBIN ARBITRATION");

        @(negedge clk);

        mode = 1'b1;
        req = 2'b11;
        done = 0;

        m0_addr  = 32'h00000005;
        m0_write = 1;
        m0_wdata = 32'hAAAA1234;

        m1_addr  = 32'h0000100A;
        m1_write = 1;
        m1_wdata = 32'hBBBB5678;

        wait (grant == 2'b01 || grant == 2'b10);

        first_rr_grant = grant;

        $display("FIRST ROUND-ROBIN GRANT = %b", first_rr_grant);

        wait (ready === 1'b1);

        if (addr_valid !== 1'b1) begin
            $display("TEST 5.1 FAILED: First address invalid");
            errors = errors + 1;
        end
        else begin
            $display("TEST 5.1 PASSED: First transaction completed");
        end

        @(negedge clk);
        done = 1;

        @(negedge clk);
        done = 0;

        wait (ready === 1'b0);

        wait (
            (grant == 2'b01 || grant == 2'b10) &&
            grant != first_rr_grant
        );

        second_rr_grant = grant;

        $display("SECOND ROUND-ROBIN GRANT = %b", second_rr_grant);

        if (second_rr_grant != first_rr_grant) begin
            $display("TEST 5.2 PASSED: Round-robin changed master");
        end
        else begin
            $display("TEST 5.2 FAILED: Round-robin did not alternate");
            errors = errors + 1;
        end

        wait (ready === 1'b1);

        if (addr_valid !== 1'b1) begin
            $display("TEST 5.3 FAILED: Second address invalid");
            errors = errors + 1;
        end
        else begin
            $display("TEST 5.3 PASSED: Second transaction completed");
        end

        @(negedge clk);
        req = 0;
        done = 1;

        @(negedge clk);
        done = 0;
        mode = 0;

        repeat (2) @(posedge clk);

        $display("TEST 5 COMPLETED");

        //========================================
        // TEST 6: MASTER 1 STARVATION DETECTION
        //========================================

        $display("\nTEST 6: MASTER 1 STARVATION DETECTION");

        @(negedge clk);

        mode = 0;
        req = 2'b11;
        done = 0;

        m0_addr = 32'h00000005;
        m0_write = 1;
        m0_wdata = 32'hCCCC1234;

        m1_addr = 32'h0000100A;
        m1_write = 1;
        m1_wdata = 32'hDDDD5678;

        wait_count = 0;

        while (grant !== 2'b01 && wait_count < 10) begin
            @(posedge clk);
            #1;
            wait_count = wait_count + 1;
        end

        if (grant === 2'b01)
            $display("TEST 6.1 PASSED: M0 RECEIVED FIXED PRIORITY");
        else begin
            $display("TEST 6.1 FAILED");
            errors = errors + 1;
        end

        wait_count = 0;

        while (DUT.starved1 !== 1'b1 && wait_count < 20) begin
            @(posedge clk);
            #1;
            wait_count = wait_count + 1;
        end

        if (DUT.starved1 === 1'b1)
            $display("TEST 6.2 PASSED: M1 STARVATION DETECTED");
        else begin
            $display("TEST 6.2 FAILED");
            errors = errors + 1;
        end

        @(negedge clk);
        done = 1;

        @(negedge clk);
        done = 0;

        wait_count = 0;

        while (grant !== 2'b10 && wait_count < 10) begin
            @(posedge clk);
            #1;
            wait_count = wait_count + 1;
        end

        if (grant === 2'b10)
            $display("TEST 6.3 PASSED: M1 RECEIVED STARVATION PRIORITY");
        else begin
            $display("TEST 6.3 FAILED");
            errors = errors + 1;
        end

        if (addr_valid === 1'b1)
            $display("TEST 6.4 PASSED: M1 ADDRESS VALID");
        else begin
            $display("TEST 6.4 FAILED");
            errors = errors + 1;
        end

        wait_count = 0;

        while (ready !== 1'b1 && wait_count < 5) begin
            @(posedge clk);
            #1;
            wait_count = wait_count + 1;
        end

        if (ready === 1'b1)
            $display("TEST 6.5 PASSED: M1 MEMORY RESPONSE");
        else begin
            $display("TEST 6.5 FAILED");
            errors = errors + 1;
        end

        @(negedge clk);
        req = 0;
        done = 1;

        @(negedge clk);
        done = 0;

        repeat (2) @(posedge clk);

        $display("TEST 6 COMPLETED");

        //========================================
        // TEST 7: MASTER 0 STARVATION DETECTION
        //========================================

        $display("\nTEST 7: MASTER 0 STARVATION DETECTION");

        @(negedge clk);

        mode = 0;
        done = 0;
        req = 2'b10;

        m1_addr = 32'h0000100A;
        m1_write = 1;
        m1_wdata = 32'hEEEE1234;

        m0_addr = 32'h00000005;
        m0_write = 1;
        m0_wdata = 32'hFFFF5678;

        wait_count = 0;

        while (grant !== 2'b10 && wait_count < 10) begin
            @(posedge clk);
            #1;
            wait_count = wait_count + 1;
        end

        if (grant === 2'b10)
            $display("TEST 7.1 PASSED: M1 RECEIVED INITIAL GRANT");
        else begin
            $display("TEST 7.1 FAILED");
            errors = errors + 1;
        end

        @(negedge clk);
        req = 2'b11;

        wait_count = 0;

        while (DUT.starved0 !== 1'b1 && wait_count < 20) begin
            @(posedge clk);
            #1;
            wait_count = wait_count + 1;
        end

        if (DUT.starved0 === 1'b1)
            $display("TEST 7.2 PASSED: M0 STARVATION DETECTED");
        else begin
            $display("TEST 7.2 FAILED");
            errors = errors + 1;
        end

        @(negedge clk);
        done = 1;

        @(negedge clk);
        done = 0;

        wait_count = 0;

        while (grant !== 2'b01 && wait_count < 10) begin
            @(posedge clk);
            #1;
            wait_count = wait_count + 1;
        end

        if (grant === 2'b01)
            $display("TEST 7.3 PASSED: M0 RECEIVED STARVATION PRIORITY");
        else begin
            $display("TEST 7.3 FAILED");
            errors = errors + 1;
        end

        if (addr_valid === 1'b1)
            $display("TEST 7.4 PASSED: M0 ADDRESS VALID");
        else begin
            $display("TEST 7.4 FAILED");
            errors = errors + 1;
        end

        wait_count = 0;

        while (DUT.s0_select !== 1'b1 && wait_count < 10) begin
            @(posedge clk);
            #1;
            wait_count = wait_count + 1;
        end

        if (DUT.s0_select === 1'b1) begin
            @(posedge clk);
            #1;

            if (DUT.s0_ready === 1'b1)
                $display("TEST 7.5 PASSED: M0 MEMORY RESPONSE");
            else begin
                $display("TEST 7.5 FAILED: M0 MEMORY DID NOT RESPOND");
                errors = errors + 1;
            end
        end
        else begin
            $display("TEST 7.5 FAILED: SLAVE 0 NOT SELECTED");
            errors = errors + 1;
        end

        @(negedge clk);
        req = 0;
        done = 1;

        @(negedge clk);
        done = 0;

        repeat (2) @(posedge clk);

        $display("TEST 7 COMPLETED");

        //========================================
        // TEST 8: INVALID ADDRESS REJECTION
        //========================================

        $display("\nTEST 8: INVALID ADDRESS REJECTION");

        @(negedge clk);

        mode = 0;
        req = 2'b01;
        done = 0;

        m0_addr = 32'h00002000;
        m0_write = 1;
        m0_wdata = 32'hDEADBEEF;

        wait_count = 0;

        while (grant !== 2'b01 && wait_count < 10) begin
            @(posedge clk);
            #1;
            wait_count = wait_count + 1;
        end

        if (grant === 2'b01)
            $display("TEST 8.1 PASSED: M0 RECEIVED GRANT");
        else begin
            $display("TEST 8.1 FAILED: NO GRANT");
            errors = errors + 1;
        end

        #1;

        if (addr_valid === 1'b0)
            $display("TEST 8.2 PASSED: INVALID ADDRESS DETECTED");
        else begin
            $display("TEST 8.2 FAILED: INVALID ADDRESS NOT DETECTED");
            errors = errors + 1;
        end

        if (
            DUT.s0_select === 1'b0 &&
            DUT.s1_select === 1'b0
        )
            $display("TEST 8.3 PASSED: NO SLAVE SELECTED");
        else begin
            $display("TEST 8.3 FAILED: SLAVE SELECTED");
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        if (ready === 1'b0)
            $display("TEST 8.4 PASSED: INVALID TRANSACTION REJECTED");
        else begin
            $display("TEST 8.4 FAILED: INVALID TRANSACTION RESPONDED");
            errors = errors + 1;
        end

        @(negedge clk);
        req = 0;
        done = 1;

        @(negedge clk);
        done = 0;

        repeat (2) @(posedge clk);

        $display("TEST 8 COMPLETED");

        //========================================
        // TEST 9: SIMULTANEOUS MASTER REQUESTS
        //========================================

        $display("\nTEST 9: SIMULTANEOUS MASTER REQUESTS");

        @(negedge clk);

        mode = 1;
        req = 2'b11;
        done = 0;

        m0_addr = 32'h00000020;
        m0_write = 1;
        m0_wdata = 32'h11112222;

        m1_addr = 32'h00001020;
        m1_write = 1;
        m1_wdata = 32'h33334444;

        wait (grant == 2'b01 || grant == 2'b10);

        first_rr_grant = grant;

        $display("TEST 9.1: FIRST GRANT = %b", first_rr_grant);

        wait (ready === 1'b1);

        if (grant == 2'b01 || grant == 2'b10)
            $display("TEST 9.2 PASSED: GRANT IS ONE-HOT");
        else begin
            $display("TEST 9.2 FAILED");
            errors = errors + 1;
        end

        // Complete first transaction.
        @(negedge clk);
        done = 1;

        @(negedge clk);
        done = 0;

        wait (ready === 1'b0);

        wait (
            (grant == 2'b01 || grant == 2'b10) &&
            grant != first_rr_grant
        );

        second_rr_grant = grant;

        $display("TEST 9.3: SECOND GRANT = %b", second_rr_grant);

        if (second_rr_grant != first_rr_grant)
            $display("TEST 9.4 PASSED: BOTH MASTERS SERVICED");
        else begin
            $display("TEST 9.4 FAILED");
            errors = errors + 1;
        end

        wait (ready === 1'b1);

        $display("TEST 9.5 PASSED: SECOND TRANSACTION COMPLETED");

        @(negedge clk);
        req = 0;
        done = 1;

        @(negedge clk);
        done = 0;
        mode = 0;

        repeat (2) @(posedge clk);

        $display("TEST 9 COMPLETED");

        //========================================
        // TEST 10: MULTIPLE CONSECUTIVE TRANSACTIONS
        //========================================

        $display("\nTEST 10: MULTIPLE CONSECUTIVE TRANSACTIONS");

        memory_transaction(
            0, 1'b1,
            32'h00000020,
            32'hA1A2A3A4,
            32'hA1A2A3A4
        );

        memory_transaction(
            0, 1'b0,
            32'h00000020,
            32'h00000000,
            32'hA1A2A3A4
        );

        memory_transaction(
            1, 1'b1,
            32'h00001020,
            32'hB1B2B3B4,
            32'hB1B2B3B4
        );

        memory_transaction(
            1, 1'b0,
            32'h00001020,
            32'h00000000,
            32'hB1B2B3B4
        );

        $display("TEST 10 COMPLETED");

        //========================================
        // TEST 11: RESET DURING ACTIVE TRANSACTION
        //========================================

        $display("\nTEST 11: RESET DURING ACTIVE TRANSACTION");

        @(negedge clk);

        mode = 0;
        req = 2'b01;
        done = 0;

        m0_addr = 32'h00000030;
        m0_write = 1;
        m0_wdata = 32'h55556666;

        wait_count = 0;

        while (grant !== 2'b01 && wait_count < 10) begin
            @(posedge clk);
            #1;
            wait_count = wait_count + 1;
        end

        if (grant === 2'b01)
            $display("TEST 11.1 PASSED: TRANSACTION STARTED");
        else begin
            $display("TEST 11.1 FAILED: NO GRANT");
            errors = errors + 1;
        end

        // Assert reset during active transaction.
        @(negedge clk);
        rst = 1;

        #1;

        if (
            grant === 2'b00 &&
            DUT.s0_select === 1'b0 &&
            DUT.s1_select === 1'b0
        )
            $display("TEST 11.2 PASSED: RESET CLEARED CONTROL SIGNALS");
        else begin
            $display("TEST 11.2 FAILED: RESET DID NOT CLEAR SIGNALS");
            errors = errors + 1;
        end

        repeat (2) @(negedge clk);

        req = 0;
        done = 0;
        rst = 0;

        repeat (2) @(posedge clk);
        #1;

        if (grant === 2'b00)
            $display("TEST 11.3 PASSED: SYSTEM RECOVERED AFTER RESET");
        else begin
            $display("TEST 11.3 FAILED: SYSTEM DID NOT RECOVER");
            errors = errors + 1;
        end

        $display("TEST 11 COMPLETED");

        //========================================
        // TEST 12: RANDOMIZED MEMORY VERIFICATION
        //========================================

        $display("\nTEST 12: RANDOMIZED WRITE AND READ-BACK");

        begin : RANDOM_TEST

            integer random_master;
            integer random_address;
            integer random_index;

            reg [31:0] random_data;

            for (
                random_index = 0;
                random_index < 20;
                random_index = random_index + 1
            ) begin

                random_master = $urandom_range(0, 1);

                if (random_master == 0) begin
                    random_address = $urandom_range(0, 255);
                end
                else begin
                    random_address =
                        4096 + $urandom_range(0, 255);
                end

                random_data = $urandom;

                $display("--------------------------------------");

                $display(
                    "RANDOM ITERATION %0d",
                    random_index + 1
                );

                $display("MASTER = %0d", random_master);
                $display("ADDRESS = %h", random_address);
                $display("DATA = %h", random_data);

                // Random write.
                memory_transaction(
                    random_master,
                    1'b1,
                    random_address,
                    random_data,
                    random_data
                );

                // Read back the same address.
                memory_transaction(
                    random_master,
                    1'b0,
                    random_address,
                    32'h00000000,
                    random_data
                );

            end

        end

        $display("TEST 12 COMPLETED");

        //========================================
        // FUNCTIONAL COVERAGE REPORT
        //========================================

        $display("\n======================================");
        $display("FUNCTIONAL COVERAGE REPORT");
        $display("======================================");

        $display(
            "Overall Coverage = %0.2f%%",
            axi_cov.get_coverage()
        );

        $display("--------------------------------------");

        if (errors == 0) begin
            $display("ALL 12 TESTS PASSED SUCCESSFULLY");
            $display("MEMORY READ/WRITE: PASSED");
            $display("ROUND-ROBIN ARBITRATION: PASSED");
            $display("STARVATION DETECTION: PASSED");
            $display("INVALID ADDRESS: PASSED");
            $display("SIMULTANEOUS REQUESTS: PASSED");
            $display("RESET RECOVERY: PASSED");
            $display("RANDOMIZED VERIFICATION: PASSED");
        end
        else begin
            $display(
                "VERIFICATION FAILED: %0d ERRORS DETECTED",
                errors
            );
        end

        $display("======================================");

        $finish;

    end

    //========================================
    // SIMULATION TIMEOUT
    //========================================

    initial begin
        #10000;
        $display("TIMEOUT: Simulation stopped");
        $finish;
    end

endmodule