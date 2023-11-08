#!/usr/bin/env python

import enum
import itertools
import logging
import os
import time

import pytest
import cocotb_test.simulator

from scapy.layers.l2 import Ether

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.utils import get_time_from_sim_steps
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame
from cocotbext.axi.stream import define_stream

# Create the PFC interface with the DUT
#PFCBus, PFCTransaction, PFCSource, PFCSink, PFCMonitor = define_stream("PFC", 
#        signals=["addr","opcode","priority_enable","time_vector"]
#)

class TB:
    def __init__(self, dut):
        self.dut = dut

        # We get the logger and log the debug signals
        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        # We set the clock period
        self.clk_period = 6.4

        # We launch two coroutines for concurrent execution
        cocotb.start_soon(Clock(dut.clk, self.clk_period, units="ns").start())

        #self.source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk, dut.rst)

        # Define the interfaces
        #self.source = PFCSource(PFCBus.from_prefix(dut, "s_pfc"), dut.clk, dut.rst)
        self.sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk, dut.rst)

        # (Debug) Print the source methods
        #all_attributes = dir(self.source)
        #methods = [attribute for attribute in all_attributes if callable(getattr(self.source, attribute))]
        #print(methods)

        #sleep(5)

    # We define a reset coroutine where we set the rst signal 0-1-0
    async def reset(self):
        self.dut.rst.setimmediatevalue(0)
        self.dut.transmit_enable.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)

    # We enable the transmit enable signal
    async def transmit_enable(self):
        self.dut.transmit_enable.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.transmit_enable.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)

    # We disable the transmit enable signal
    async def transmit_disable(self):
        self.dut.transmit_enable.setimmediatevalue(1)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.transmit_enable.value = 0
        await RisingEdge(self.dut.clk)

    # We enable PFC 
    async def pfc_enable(self):
        self.dut.s_pfc_addr.setimmediatevalue(0x0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.s_pfc_addr.setimmediatevalue(0x111111111111)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        print(self.dut.s_pfc_addr)
        time.sleep(2)

    # We disable PFC 
    async def pfc_disable(self):
        self.dut.s_pfc_addr.setimmediatevalue(0b000100000100010000100010000100010000100010000100)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.s_pfc_addr.setimmediatevalue(0x0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        print(self.dut.s_pfc_addr)
        time.sleep(2)


async def test(dut, payload_lengths=None, payload_data=None):

    tb = TB(dut)


    await tb.reset()
    await tb.transmit_enable()
    await tb.pfc_disable()

    cur_id = 1

    #print("DESPUÉS DEL RESET")

    test_frames = []
    test_pkts = []

    test_data = bytearray(b'\x01\x80\xC2\x00\x00\x01\x00\x00')

    #for payload in [payload_data(x) for x in payload_lengths()]:
        # we create the Ethernet packet
    #    eth = Ether(src='5A:51:52:53:54:5', dst='01:00:00:C2:80:01')
    #    test_pkt = eth / payload
    #    test_frame = AxiStreamFrame(test_pkt.build())
    #    test_pkts.append(test_pkt)
    #    test_frame = AxiStreamFrame(test_pkt.build())
    #    test_frames.append(test_frame)

        #print("PAQUETE")
        #print(test_frame)
        #time.sleep(1)

        #await tb.source.send(test_frame)
    await tb.pfc_enable() 
        #rx_frame = await tb.sink.recv()
    print(tb.dut.prueba)
    time.sleep(2)
    assert tb.dut.prueba == 0
        #assert rx_frame.tid == test_frame.tid
        #assert rx_frame.tdest == test_frame.tdest
        #assert not rx_frame.tuser

    
    #test_frame = AxiStreamFrame(test_data)
    #test_frame.tid = cur_id
    #test_frame.tdest = cur_id
    

    """
    for test_data in [payload_data(x) for x in payload_lengths()]:
        test_frame = AxiStreamFrame(test_data)
        test_frame.tid = cur_id
        test_frame.tdest = cur_id

        test_frames.append(test_frame)
        await tb.source.send(test_frame)

    for test_frame in test_frames:
        rx_frame = await tb.sink.recv()

        assert rx_frame.tdata == test_frame.tdata
        assert rx_frame.tid == test_frame.tid
        assert rx_frame.tdest == test_frame.tdest
        assert not rx_frame.tuser
    """

    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])

#def size_list():
#    return list(range(60, 128)) + [512, 1514, 9214] + [60]*10

def size_list():
    return list(range(1, 128)) + [512, 1500, 9200] + [46]*10

def incrementing_payload(length):
    #return bytearray(itertools.islice(itertools.cycle(range(256)), length))
    return bytes(itertools.islice(itertools.cycle(range(256)), length))


def cycle_en():
    return itertools.cycle([0, 0, 0, 1])

if cocotb.SIM_NAME:

    factory = TestFactory(test)
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload])
    factory.generate_tests()

# cocotb-test

tests_dir = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
lib_dir = os.path.abspath(os.path.join(rtl_dir, '..', 'lib'))
axis_rtl_dir = os.path.abspath(os.path.join(lib_dir, 'axis', 'rtl'))

@pytest.mark.parametrize("data_width", [64])
async def test_mqnic_pfc_rx(request, data_width):
    dut = "mqnic_pfc_rx"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    print("---------------------------------------")
    print(module)
    print("---------------------------------------")

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
        os.path.join(rtl_dir, "pfc_rx_fifo.v")
    ]

    parameters = {}

    parameters['DATA_WIDTH'] = data_width
    parameters['KEEP_ENABLE'] = int(parameters['DATA_WIDTH'] > 8)
    parameters['KEEP_WIDTH'] = (parameters['DATA_WIDTH'] + 7) // 8
    parameters['LAST_ENABLE'] = 1
    parameters['ID_ENABLE'] = 1
    parameters['ID_WIDTH'] = 8
    parameters['DEST_ENABLE'] = 1
    parameters['DEST_WIDTH'] = 8
    parameters['USER_ENABLE'] = 1
    parameters['USER_WIDTH'] = 1

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    sim_build = os.path.join(tests_dir, "sim_build",
        request.node.name.replace('[', '-').replace(']', ''))

    cocotb_test.simulator.run(
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env,
    )
