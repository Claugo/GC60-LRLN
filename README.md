# GC60-LRLN

LRLN (Local Residue Lattice Navigation) \& GC-60 Model

This project introduces a deterministic paradigm shift in prime candidate screening for high-magnitude numbers (e.g., $10^{19}$ and beyond). Instead of actively testing individual numbers, the engine treats search windows as passive containers that only intersect the geometric projections of mathematically relevant divisors.



\---



\## 🚀 Performance Highlights



By leveraging smart residue classification, the engine filters out irrelevant divisors at the doorstep, completely bypassing heavy 128-bit modular reductions during the parallel sieving phase. 



Under optimal thermal conditions, the multi-threaded Julia implementation achieves outstanding results:

\* \*\*Magnitude ($n$):\*\* $10^{19}$

\* \*\*Search Window ($W$):\*\* $10^6$ (1 million units)

\* \*\*Parallel Sieve Time:\*\* \*\*54 milliseconds\*\* (on standard 8-thread architectures)

\* \*\*Divisor Reduction:\*\* Effectively slashes the active pool from 49 million down to just 813,511 smart elements.



\---



\## 📖 Detailed Documentation (Italian Language)



This README serves as a quick technical overview of the source code and performance benchmarks\[cite: 4]. For the complete scientific breakdown—including the deep theoretical framework, geometric proofs, and the complete mathematical design of the GC-60 and LRLN methods—please refer to the official paper published on \*\*Zenodo\*\*.



> ⚠️ \*\*Note:\*\* The comprehensive scientific documentation hosted on Zenodo is written entirely in \*\*Italian\*\*.



🔗 \*\*\[Insert your Zenodo DOI Link Here]\*\*



\---



\## 📁 Repository Structure



\* \*\*`julia/`\*\*: High-performance parallel implementations of the LRLN Master Engine (Native Two-Phase Mode).

\* \*\*`python/`\*\*: Original proof-of-concept scripts and validation routines utilizing SymPy's `nextprime`.



\---



\## 🌐 Project Links



\* \*\*Official Website:\*\* \[gc57crypto.net](https://www.gc57crypto.net) — Video explanations and visual animations of the GC57/GC-60 properties.

\* \*\*Author ORCID:\*\* \[https://orcid.org/0009-0005-9020-0691](https://orcid.org/0009-0005-9020-0691)



\---



\## 📄 License



\* The software source code contained in this repository is licensed under the \*\*MIT License\*\*.

\* The scientific paper and text documentation are licensed under the \*\*Creative Commons Attribution 4.0 International (CC BY 4.0)\*\* license.

