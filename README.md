# Claugo: Local Residue Lattice Navigation (LRLN) and GC-60 Model

This project introduces a deterministic paradigm shift in prime candidate screening for high-magnitude numbers (e.g., 10^19, 10^21, and beyond). Instead of actively testing individual numbers, the LRLN engine treats search windows as passive containers that only intersect the geometric projections of mathematically relevant divisors according to the GC-60 model.

---

## Performance Highlights

By leveraging smart residue classification and the **Pure Gap Navigation** logic, the engine filters out irrelevant divisors at the doorstep, completely bypassing heavy 128-bit modular reductions during the parallel sieving phase. 

### Benchmark Environment
* **Magnitude (n):** 10^19
* **Search Window (W):** 1,000,000 (1 million units)
* **Primorial Base (P):** 510,510
* **Smart Divisors Extracted:** 813,511
* **Hardware Configuration:** 16 Symmetric Hardware Threads (both environments)

---

## Empirical Verification (3-Run Execution Matrix)

To guarantee deterministic consistency and scientific transparency, the LRLN Pure Gap Mode has been stress-tested across three consecutive runs in both Native C++ and Julia.

| Environment | Operational Phase | Run 1 | Run 2 | Run 3 | Structural Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **C++ (GCC)** <br>*16 Threads* | Phase 1 (Structures)<br>Phase 2+3 (Smart Divisors)<br>Phase 4 (Sieving Engine)<br>Phase 5 (Export Routine)<br>**TOTAL TIME** | 0.048500 s<br>0.818826 s<br>0.021021 s<br>Included<br>**0.892 s** | 0.047268 s<br>0.812070 s<br>0.020800 s<br>Included<br>**0.883 s** | 0.047648 s<br>0.812970 s<br>0.021946 s<br>Included<br>**0.886 s** | Wheel Ready<br>Smart Pool Isolated<br>Window Cleared<br>Suffix File Saved<br>**Average: 0.887 s** |
| **JULIA** <br>*16 Threads* | Phase 1 (Structures)<br>Phase 2+3 (Smart Divisors)<br>Phase 4 (Sieving Engine)<br>Phase 5 (Export Routine)<br>**TOTAL TIME** | Included<br>1.019480 s<br>0.056549 s<br>0.003350 s<br>**1.143 s** | Included<br>1.041550 s<br>0.059589 s<br>0.003684 s<br>**1.169 s** | Included<br>1.023440 s<br>0.057264 s<br>0.003584 s<br>**1.147 s** | Wheel Ready<br>Smart Pool Isolated<br>Window Cleared<br>Suffix File Saved<br>**Average: 1.153 s** |

### Key Technical Insights from the Data
* **Magnitude De-coupling (Phase 4):** The most significant mathematical outcome is shown in Phase 4 (the actual parallel sieve). On 16 threads, native C++ clears the entire 1-million window in just **~21 milliseconds**, while Julia stabilizes around **~57 milliseconds**. This confirms that once the 813,511 smart divisors are mapped, the local sieve operates purely on fast 64-bit offsets, entirely isolated from the 128-bit scale of the global magnitude ($10^{19}$).
* **Deterministic Rigidity:** The execution times exhibit near-zero variance across subsequent runs (fluctuations $< 10$ ms in C++, $< 25$ ms in Julia). This strict predictability empirical proves that the LRLN engine bypasses probabilistic behaviors, following a rigid trajectory dictated exclusively by the lattice topology.
* **AOT vs. JIT Convergence:** By explicitly launching Julia with 16 threads, the time needed for divisor navigation (Phase 2+3) drops to just **1.02 seconds**, converging tightly with C++'s **0.81 seconds**. Residual gaps are strictly due to runtime-level array bounds checking and dynamic memory abstractions.

*Both engines output the exact same cryptographic vector of **23,069 real prime candidates**.*

---

## Detailed Documentation (Italian Language)

This README serves as a quick technical overview of the source code and performance benchmarks. For the complete scientific breakdown, including the deep theoretical framework, geometric proofs, and the complete mathematical design of the GC-60 and LRLN methods, please refer to the official paper published on Zenodo.

> **Note:** The comprehensive scientific documentation hosted on Zenodo is written entirely in Italian.

🔗 [Insert your Zenodo DOI Link Here]

---

## Repository Structure

* **cpp/**: Ultra-high-performance native C++17 implementation supporting 128-bit arithmetic, automatic hardware thread detection, and dynamic command-line arguments.
* **julia/**: High-performance parallel implementation of the LRLN Master Engine running in Pure Gap Mode.
* **python/**: Original proof-of-concept scripts and validation routines developed during the initial discovery phases.
---

## Project Links

* **Official Website:** [beyondprime64.org](https://www.beyondprime64.org) GC-60 properties.
* **Author ORCID:** https://orcid.org/0009-0005-9020-0691

---

## License

* The software source code contained in this repository is licensed under the MIT License.
* The scientific paper and text documentation are licensed under the Creative Commons Attribution 4.0 International (CC BY 4.0) license.
