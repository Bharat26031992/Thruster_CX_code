<p align="center">
  <img src="Original/PY-BEMCS-ICON.png" alt="PY-BEMCS Ion Extraction Simulation" width="700">
</p>

<h1 align="center">
  Python Beam Extraction & Monte Carlo Simulator (PY-BEMCS)
</h1>

<p align="center">
  <strong>A high-fidelity simulation tool for ion beam extraction, charge-exchange (CEX) physics, ion optics erosion, and multiphysics studies in ion thrusters, NBI, and ion sources.</strong>
</p>

---

## 🌟 Key Updates in this Version

This version introduces major improvements in architecture, configuration, diagnostics, and multi-core benchmarking:

* **Modular JSON Configuration (`config.json`)**: Migrated from legacy INI format to a structured `config.json` supporting arbitrary $N$-grid optics setups, discharge chamber dimensions, grid transparency, and custom cross-section datasets with live reload support.
* **In-App Standalone Executable Builder**: Built-in PyInstaller builder available directly from the GUI (**Settings → Build .exe...**) with a dedicated background thread (`QThread`) and real-time progress dialog.
* **Robust Physics Engine & Fallback Kernels**: Added vectorized CPU fallback kernels for particle pushing, charge deposition, and thermal conduction, ensuring full portability across environments without Taichi/GPU dependency.
* **Multi-Core Benchmarking Suite (`benchmarks/`)**: Parallel parameter sweep scripts to evaluate CEX erosion, Electron Backstreaming (EBS) limit, beam impingement / grid scraping, and perveance vs divergence across multiple grid gaps simultaneously.
* **Diagnostics & Data Export**: Integrated Ion Energy Distribution Function (IEDF) tracking, interactive log-log spline fitting for reaction cross-sections, and progress dialogs for CSV/GIF exports.
* **Extended MATLAB Suite**: Updated digital twin models and parametric breakdown scripts in `Matlab/Improvements/`.

---

## 📁 Repository Structure

```text
PY-BEMCS/
├── Python/
│   ├── main.py                         # Main PyQt5 GUI application with live visualization & diagnostics
│   ├── physics_engine.py               # DigitalTwinSimulator physics backend (Taichi GPU + CPU fallback)
│   ├── run_simulation_from_config.py   # Headless simulation runner reading from config.json
│   ├── config.json                     # Primary JSON simulation configuration file
│   ├── sample.txt                      # Example custom cross-section / SEE data table
│   ├── benchmarks/                     # Multi-core parametric validation & sweep scripts
│   │   ├── benchmark_cex.py            # CEX erosion rate vs. neutral density sweep
│   │   ├── benchmark_ebs.py            # EBS saddle-point potential vs. accelerator voltage
│   │   ├── benchmark_impingement.py    # Primary ion grid impingement fraction vs. perveance
│   │   ├── benchmark_perveance.py      # Beam divergence vs. perveance across multiple gaps
│   │   └── benchmark_perveance_Vs_Sweep.py # Divergence vs. Screen grid voltage
│   └── docs/                           # Manuals and physics documentation
├── Matlab/
│   ├── TransientDigitalTwin.m          # Original MATLAB EOL and erosion model
│   ├── charge_exchange_code.m          # MATLAB plume CEX MCC model
│   ├── mission_analyses.m              # Propulsion mission performance analysis
│   └── Improvements/                   # Advanced transient digital twin & breakdown scripts
└── README.md
```

---

## ⚡ Core Physics Capabilities

- **Vectorized Particle Tracking**: Self-consistent PIC beam extraction based on the Bohm sheath criterion and plasma meniscus dynamics.
- **Charge-Exchange (CEX) Collisions**: Probabilistic Monte Carlo Collision (MCC) modeling with Birdsall/Roy cross-section formulation or custom imported experimental tables.
- **Multiphysics Grid Erosion & Remeshing**: In-situ cell damage accumulation, sputter erosion rate modeling, and structural cell removal.
- **Cantilever Thermal Deformation**: Euler-Bernoulli cantilever deformation model driven by thermal expansion ($\delta = \frac{\alpha \Delta T L^2}{2 t}$), causing dynamic deflection of grid aperture boundaries.
- **Secondary Electron Emission (SEE) & RF Co-Extraction**: Modeling secondary electron yield on grid surfaces and multi-species RF extraction.
- **Material Presets**: Built-in refractory metal properties (Molybdenum, Steel SS316, Titanium, Graphite) and fully customizable thermal/sputter parameters.

---

## 🚀 Quick Start & Installation

### 1. Prerequisites & Environment Setup
Python 3.10+ (Python 3.12 recommended) is required.

```bash
# Navigate to the Python directory
cd Python

# Create and activate virtual environment
# Windows (PowerShell):
python -m venv .venv
.venv\Scripts\Activate.ps1

# Linux / macOS:
python3 -m venv .venv
source .venv/bin/activate

# Upgrade pip
pip install --upgrade pip
```

### 2. Install Dependencies
```bash
pip install numpy scipy matplotlib PyQt5 Pillow taichi pyinstaller
```

---

## 🖥️ Running the Application

### A. Interactive GUI Application
```bash
python main.py
```
* **Load/Reload Configurations**: Use **Settings → Open Config JSON...** or **Settings → Reload config.json** to hot-swap parameters.
* **Build Standalone Executable**: Go to **Settings → Build .exe...**, select a destination folder, and track real-time compilation progress.
* **Manage Species & Materials**: Configure ions via **Beam → Ion Species...**, materials via **Materials → Grid Material...**, and cross-sections via **Beam → Cross-Section Manager...**.

### B. Headless Execution via `config.json`
To run simulations in headless / batch mode without opening the GUI:
```bash
python run_simulation_from_config.py
```

### C. Multi-Core Benchmark Sweeps
Run automated multi-process parametric sweeps:
```bash
python benchmarks/benchmark_cex.py
python benchmarks/benchmark_ebs.py
python benchmarks/benchmark_impingement.py
python benchmarks/benchmark_perveance.py
python benchmarks/benchmark_perveance_Vs_Sweep.py
```

---

## ⚙️ Configuration File (`config.json`)

The simulator is configured via `config.json`. Below is an overview of key sections:

```json
{
  "beam_species": {
    "mass_amu": 131.293,
    "charge_state": 1
  },
  "grid_material": {
    "preset": "Molybdenum"
  },
  "simulation": {
    "n0_plasma": 7.73e17,
    "Te_up": 8.5,
    "Ti": 0.034,
    "Tn": 400.0,
    "n0": 5.27e18,
    "sim_mode": "Both"
  },
  "grids": [
    { "V": 1300.0, "t": 1.2, "gap": 0.9, "r": 1.3, "cham": 20.0 },
    { "V": -150.0, "t": 0.6, "gap": 0.5, "r": 0.8, "cham": 0.0 },
    { "V": 50.0,   "t": 0.5, "gap": 4.0, "r": 1.2, "cham": 0.0 }
  ],
  "cross_sections": {
    "cx_file": "",
    "see_file": "",
    "custom_file": "",
    "spline_smoothing": 0.0
  }
}
```

---

## 📊 MATLAB Models

1. Open MATLAB in the repository directory.
2. Run standard or improved models:
   ```matlab
   TransientDigitalTwin          % Baseline MATLAB erosion & EOL simulation
   charge_exchange_code          % Plume CEX Faraday probe analysis
   ```
3. Advanced models located in `Matlab/Improvements/` include extended high-voltage breakdown evaluations and thermal deformation tracking.

---

## 📄 License & Attribution

This project is licensed under the **Creative Commons Attribution-NonCommercial 4.0 International License (CC BY-NC 4.0)**.

### Original Author & Citation
* **Original Author**: Dr. Bharat Singh Rawat ([GitHub](https://github.com/Bharat-Singh-Rawat/PY-BEMCS))
* **BibTeX Citation**:
```bibtex
@software{PY-BEMCS,
  author       = {Bharat Singh Rawat},
  title        = {Python Beam Extraction and Monte Carlo Simulator (PY-BEMCS)},
  year         = {2026},
  publisher    = {GitHub},
  journal      = {GitHub repository},
  howpublished = {\url{https://github.com/Bharat-Singh-Rawat/PY-BEMCS}},
}
```
