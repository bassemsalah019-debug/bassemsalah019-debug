# 🛢️ Well Log Petrophysical Analysis

**Personal Project — Petroleum Data Science | 2025**
**Author:** Bassem Salah

---

## 📋 Overview

A complete 7-stage petrophysical well log analysis pipeline built in Python using a real LAS file — reproducing the full Petrel/Techlog workflow in open-source Python.

## 🔬 7-Stage Pipeline

| Stage | Task | Method |
|-------|------|--------|
| 1 | LAS File Ingestion | `lasio` library |
| 2 | Log QC & Curve Validation | Null detection, depth alignment |
| 3 | Vshale Calculation | GR log linear normalization |
| 4 | Porosity Estimation | Density / Neutron / Sonic |
| 5 | Water Saturation | Archie Equation: Sw = √(a·Rw / φᵐ·Rt) |
| 6 | Net Pay Cutoffs | Vsh < 50%, φ > 10%, Sw < 60% |
| 7 | OOIP & EUR Estimation | Volumetric method + Recovery Factor |

## 📊 Outputs

- Multi-track log display (GR, Resistivity, Porosity, Vshale, Sw, Net Pay flag)
- Porosity vs Water Saturation crossplots
- Formation zone summary table
- OOIP volumetric estimate
- EUR with recovery factor

## ⚡ Why This Matters

This project bridges petroleum geoscience domain knowledge with modern Python data science — a rare combination demonstrating that AI/ML skills can directly replace expensive proprietary software.

## 🛠 Technologies
Python · lasio · Matplotlib · NumPy · Pandas · Jupyter
