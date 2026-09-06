<p align="center">
  <img src="Original/PY-BEMCS-ICON.png" alt="PY-BEMCS Ion Extraction Simulation" width="700">
</p>

<h1 align="center">
  Python Beam Extraction & Monte Carlo Simulator (PY-BEMCS)
</h1>

<p align="center">
  <strong>A high-fidelity 2D3V electrostatic Particle-in-Cell (PIC) & Monte Carlo Collision (MCC) simulation suite for gridded ion thrusters, neutral beam injectors (NBI), and advanced plasma extraction systems.</strong>
</p>

<p align="center">
  <a href="#-key-features--upgrades">Key Features</a> •
  <a href="#-numerical-controls--physics-validation">Physics Controls</a> •
  <a href="#-installation--setup">Installation</a> •
  <a href="#-running-the-code">Usage</a> •
  <a href="#-configuration-guide-configjson">Configuration</a> •
  <a href="#-multi-core-benchmarks">Benchmarks</a> •
  <a href="#-credits--authorship">Credits</a>
</p>

---

## 🌟 Key Features & Upgrades

* **Dual-Kernel Architecture (Taichi GPU + CPU Fallback)**: High-throughput 2D3V Boris particle advancement and bilinear charge deposition accelerated with Taichi (CUDA, Metal, Vulkan) with seamless, vectorized pure-NumPy CPU fallback kernels for maximum portability across any machine.
* **Automated Numerical Physics Controls**: Built-in automated checks for spatial Debye length resolution ($\Delta x, \Delta y \le \lambda_{\mathrm{D}}$), plasma frequency integration limits ($\Delta t \le 2\pi/\omega_{\mathrm{pi}}$), and CFL velocity limits ($v_{\max} \Delta t \le \Delta x$).
* **Modular JSON Configuration (`config.json`)**: Replaced legacy INI format with a clean, extensible `config.json` supporting arbitrary $N$-grid optics, discharge chamber parameters, and reaction cross-section tables, complete with in-app hot-reloading.
* **In-App Standalone Executable Builder**: Compile the application into a single-file executable directly from the GUI (**Settings → Build .exe...**) using an asynchronous background thread (`QThread`) with live progress milestone tracking.
* **Multi-Core Benchmarking Suite (`benchmarks/`)**: Automated parallel multi-process parametric sweeps for CEX erosion rates, Electron Backstreaming (EBS) limits, primary beam impingement / grid scraping, and perveance-divergence curves.
* **Thermo-Mechanical Cantilever Grid Deflection**: Real-time modeling of grid aperture deformation driven by Euler--Bernoulli cantilever thermal expansion ($\delta = \frac{\alpha \Delta T L^2}{2t}$), with dynamic mesh distortion and Poisson refactorization.
* **Live Telemetry & Diagnostics**: Real-time tracking of 95th-percentile beam divergence ($\theta_{95}$), centerline saddle-point potential, Ion Energy Distribution Function (IEDF), and asynchronous progress dialogs for CSV, phase-space, and GIF exports.

---

## 🔬 Numerical Controls & Physics Validation

When generating the simulation domain (`build_domain`), the engine automatically verifies the physical consistency of your grid resolution and numerical time step:

1. **Debye Length Resolution ($\lambda_{\mathrm{D}}$)**:
   $$\lambda_{\mathrm{D}} = \sqrt{\frac{\varepsilon_0 T_{\mathrm{e,up}}}{e \cdot (0.61 n_0)}}, \qquad \Delta x \le \lambda_{\mathrm{D}} \quad \text{and} \quad \Delta y \le \lambda_{\mathrm{D}}$$
   Prevents unphysical numerical grid heating and space-charge instabilities.
2. **Plasma Frequency Integration Limit**:
   $$\omega_{\mathrm{pi}} = \sqrt{\frac{n_0 e^2}{m_{\mathrm{ion}} \varepsilon_0}}, \qquad \Delta t \le \frac{2\pi}{\omega_{\mathrm{pi}}}$$
   Ensures the time step is fine enough to resolve high-frequency collective plasma oscillations.
3. **Courant--Friedrichs--Lewy (CFL) Velocity Bound**:
   $$v_{\max} = v_{\mathrm{Bohm}} + 4 v_{\mathrm{thermal,i}} = \sqrt{\frac{Z e T_{\mathrm{e}}}{m_{\mathrm{ion}}}} + 4\sqrt{\frac{Z e T_{\mathrm{i}}}{m_{\mathrm{ion}}}}, \qquad \frac{\Delta x}{\Delta t} \ge v_{\max}, \quad \frac{\Delta y}{\Delta t} \ge v_{\max}$$
   Guarantees that fast particles do not skip entire mesh cells within a single time increment.
4. **Dynamic Domain & Geometry Modes**:
   - **Axial Extent**: $L_x = \SI{1.5}{\milli\meter} + \sum_k (t_k + g_k) + \SI{3.0}{\milli\meter}$ dynamically computed from the grid stack.
   - **`half_hole`**: Axisymmetric half-aperture with specular symmetry reflection at $y = 0$.
   - **`one_hole`**: Full single-aperture extraction domain with periodic boundary conditions along $y$.
   - **`two_holes`**: Dual-aperture coupling domain with periodic boundaries along $y$.

---

## 📁 Repository Structure

```text
Python/
├── main.py                         # PyQt5 GUI application with live diagnostics & .exe builder
├── physics_engine.py               # DigitalTwinSimulator (Taichi GPU + NumPy CPU kernels)
├── run_simulation_from_config.py   # Headless simulation runner reading config.json
├── config.json                     # Primary JSON simulation configuration
├── sample.txt                      # Example custom cross-section / SEE data table
├── benchmarks/                     # Parallel multi-core physics sweep scripts
│   ├── benchmark_cex.py            # CEX erosion rate vs. neutral density sweep
│   ├── benchmark_ebs.py            # EBS saddle-point potential vs. accelerator voltage
│   ├── benchmark_impingement.py    # Primary ion grid impingement fraction vs. perveance
│   ├── benchmark_perveance.py      # Beam divergence vs. perveance across multiple gaps
│   └── benchmark_perveance_Vs_Sweep.py # Divergence vs. Screen grid voltage sweep
├── docs/                           # Physics and user manuals (LaTeX & PDF)
│   ├── PY-BEMCS_Manual.tex         # Complete LaTeX physics reference manual
│   └── PY-BEMCS_Manual.pdf         # Compiled user manual
└── README.md                       # This documentation file
```

---

## 🚀 Installation & Setup

### 1. Prerequisites
Python 3.10+ (Python 3.12 recommended).

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

## 💻 Running the Code

### 1. Interactive Graphical Application (GUI)
```bash
python main.py
```
* **Hot-Reloading Configurations**: Go to **Settings → Open Config JSON...** or **Settings → Reload config.json** to swap configurations on the fly.
* **Build Standalone Executable**: Click **Settings → Build .exe...**, select a destination directory, and track real-time compilation progress.
* **Configure Species & Materials**: Manage species via **Beam → Ion Species...**, material presets via **Materials → Grid Material...**, and custom reaction tables via **Beam → Cross-Section Manager...**.

### 2. Headless Batch Execution via `config.json`
Run simulations in headless / cluster mode without launching a GUI:
```bash
python run_simulation_from_config.py
```

### 3. Parallel Multi-Core Benchmarking Sweeps
Execute multi-core parametric physics sweeps (each grid gap runs on an independent CPU core):
```bash
python benchmarks/benchmark_cex.py
python benchmarks/benchmark_ebs.py
python benchmarks/benchmark_impingement.py
python benchmarks/benchmark_perveance.py
python benchmarks/benchmark_perveance_Vs_Sweep.py
```

---

## ⚙️ Configuration Guide (`config.json`)

The simulator is driven by `config.json`. Below is a standard multi-grid configuration:

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
    "Accel": 0.5,
    "Thresh": 10000.0,
    "sim_mode": "Both",
    "geometry": "half_hole"
  },
  "discharge_chamber": {
    "radius_m": 0.02,
    "length_m": 0.10,
    "n_cusp": 4,
    "pitch_mm": 3.0
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
  },
  "terminal_output": {
    "grid_temperatures": true,
    "beam_divergence": true,
    "saddle_point_potential": true,
    "mean_particle_energy": true,
    "iteration_time": true
  }
}
```

---

## 📊 Multi-Core Benchmarks

| Benchmark Script | Physics Parameter Swept | Objective |
| :--- | :--- | :--- |
| **`benchmark_cex.py`** | Neutral density ($n_{\mathrm{n}} = 10^{18}\dots 5\times 10^{19}\,\si{\per\meter\cubed}$) | Quantify accelerator grid erosion rates from CEX ions across multiple grid gaps. |
| **`benchmark_ebs.py`** | Accelerator voltage ($V_{\mathrm{a}} = -400\dots 0\,\si{\volt}$) | Track centerline saddle-point potential against the $-5\,\si{\volt}$ EBS risk barrier. |
| **`benchmark_impingement.py`** | Upstream plasma density / Perveance ($P = I_{\mathrm{ion}}/V_{\mathrm{tot}}^{1.5}$) | Measure the primary beam interception and grid scraping percentage. |
| **`benchmark_perveance.py`** | Plasma density over 60 points | Map beam divergence angle vs. perveance curves (underfocused, optimal, overfocused). |
| **`benchmark_perveance_Vs_Sweep.py`** | Screen voltage ($V_{\mathrm{s}} = 600\dots 2000\,\si{\volt}$) | Evaluate voltage extraction efficiency on beam divergence at constant density. |

---

## 👥 Credits & Authorship

* **Original Creator & Lead Author**:
  * **Dr. Bharat Singh Rawat** — [GitHub](https://github.com/Bharat-Singh-Rawat/PY-BEMCS) | [Email](mailto:bharat.bharat22@gmail.com)
* **Version 2.0 Architecture, Physics Controls & Diagnostic Extensions**:
  * **Nick Magrin** — [GitHub](https://github.com/nickmagrin-pixel/PY-BEMCS) | [Email](mailto:nick.magrin@gmail.com)

---

## 📄 License & Citation

This project is licensed under the **Creative Commons Attribution-NonCommercial 4.0 International License (CC BY-NC 4.0)**.

```bibtex
@software{PY-BEMCS,
  author       = {Bharat Singh Rawat and Nick Magrin},
  title        = {Python Beam Extraction and Monte Carlo Simulator (PY-BEMCS)},
  year         = {2026},
  publisher    = {GitHub},
  journal      = {GitHub repository},
  howpublished = {\url{https://github.com/nickmagrin-pixel/PY-BEMCS}},
}
```
