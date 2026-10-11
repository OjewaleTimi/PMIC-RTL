# Modular Power Management IC (PMIC) RTL & HIL Verification

> A complete synthesizable RTL suite and mixed-signal verification framework for a Power Management IC (PMIC), featuring a custom-built I2C communication protocol, a 15-cycle Break-Before-Make (BBM) power path controller, and live Hardware-in-the-Loop (HIL) validation on an Artix-7 FPGA.

---

## 🚀 Project Overview

This repository contains the custom digital logic and mixed-signal integration architecture for a modular Power Management IC. The system is designed to safely manage autonomous power handoffs between a 5.0V USB input and a 3.7V battery rail, protect system hardware from inrush current spikes, and communicate live telemetry over a custom I2C peripheral macro to an external microcontroller.

---

## ⚡ Key Architectural Features

### **1. Custom I2C Peripheral Macro (`i2c_peripheral.v`)**
*   **Built from Scratch:** Designed entirely in Verilog without pre-packaged IP cores.
*   **Protocol Handling:** Manages start/stop conditions, 7-bit slave address matching, serial clock oversampling, and acknowledge/non-acknowledge (ACK/NACK) generation over standard open-drain SDA/SCL lines.
*   **Memory-Mapped Registers:** Exposes internal system states and voltage telemetry to an external master.

### **2. Power Path Controller (`pp_controller.v`)**
*   **Finite State Machine (FSM):** Manages smooth, autonomous transitions between `STATE_DISCONNECTED`, `STATE_BATTERY`, and `STATE_USB`.
*   **Break-Before-Make (BBM) Dead-Time:** Enforces a strict 15-cycle dead-time where both path switches are driven low during rail handoffs, completely eliminating shoot-through short circuits and relying on an external 10µF bulk capacitor to sustain system voltage (`VSYS`).
*   **Asynchronous Fault Trip:** Instantly overrides normal operation upon detecting analog or digital over-current conditions (`analog_oc_fault_n`, `i2c_oc_fault`, or `master_shutdown`), forcing an immediate emergency shutdown.

### **3. Mixed-Signal Soft-Start & Inrush Current Mitigation**
*   **Transistor-Level Integration:** Verified within Cadence Virtuoso/Spectre (`pp_mixed_tb`) using back-to-back thick-oxide PMOS power switches (`pfet_g5v0d10v5`) to block reverse-leakage body-diode currents.
*   **Constant-Current Gate Driver:** Utilizes a precision current mirror to slowly discharge the massive gate capacitance ($C_{ISS}$) of the power switches, enforcing a linear voltage ramp that temporarily acts as an active variable resistor to prevent catastrophic inrush current spikes into uncharged bulk capacitors.

### **4. Telemetry & ADC Interfacing (`adc_controller.v` & `mux_sequencer.v`)**
*   **Modular Control:** Orchestrates multiplexed analog signal routing and conversion tracking.
*   **Fault Injection Testing:** Integrates with an external NodeMCU microcontroller running PWM-to-analog RC filtering to safely test real-world voltage limits and software-driven fault injection.

---

## 📂 Repository Structure

```text
├── pmic_rtl/                  # PMIC digital IP core
│   ├── pp_controller.v        # FSM with 15-cycle BBM dead-time logic
│   ├── i2c_peripheral.v       # Custom I2C slave communication macro
│   ├── mux_sequencer.v        # Multiplexer and power path routing logic
│   └── adc_controller.v       # Telemetry and XADC control interface
├── sim/                       # Simulation testbenches and mixed-signal wrappers
│   ├── pp_mixed_tb.v          # Mixed-signal testbench (Cadence/Spectre bridge)
│   └── pmic_top_tb.v          # Digital functional testbench
└── README.md                  # Project documentation
