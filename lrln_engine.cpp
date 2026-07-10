#include <iostream>
#include <vector>
#include <numeric>
#include <cmath>
#include <thread>
#include <chrono>
#include <fstream>
#include <cstdint>
#include <string>
#include <algorithm>

// --- STRUTTURE DATI ---

struct PrimorialWheel {
    uint64_t P;
    std::vector<uint64_t> jump_table;
    std::vector<int64_t> lookup_table;
    std::vector<uint64_t> offset_table;
    int64_t phi_P;
    std::vector<bool> is_coprime;
};

// --- FUNZIONI DI SERVIZIO PER INTERI A 128 BIT ---

unsigned __int128 parse_uint128(const std::string& s) {
    unsigned __int128 res = 0;
    for (char c : s) {
        if (c >= '0' && c <= '9') {
            res = res * 10 + (c - '0');
        }
    }
    return res;
}

std::string uint128_to_string(unsigned __int128 value) {
    if (value == 0) return "0";
    std::string s = "";
    while (value > 0) {
        s += (char)('0' + (value % 10));
        value /= 10;
    }
    std::reverse(s.begin(), s.end());
    return s;
}

// --- FASE 1: GAPS ESTESI FINO A MOD + 19 PER COMPLETARE TUTTE LE COLONNE ---

std::vector<uint64_t> generate_modulo_gaps() {
    std::vector<uint64_t> modulo_gap;
    uint64_t precedente = 19;

    // Estendiamo la ricerca fino a 510510 + 19 per includere i passi dei residui iniziali (+1, +11, +13, +17)
    for (uint64_t i = 23; i <= (510510 + 19); i += 2) {
        if (i % 3 != 0 && i % 5 != 0 && i % 7 != 0 &&
            i % 11 != 0 && i % 13 != 0 && i % 17 != 0) {
            modulo_gap.push_back(i - precedente);
            precedente = i;
        }
    }
    return modulo_gap;
}

PrimorialWheel generate_wheel(uint64_t P) {
    std::cout << "[FASE 1] Generazione tabelle ruota per P = " << P << "...\n";

    std::vector<uint64_t> coprimes;
    for (uint64_t x = 1; x <= P; ++x) {
        if (std::gcd(x, P) == 1) {
            coprimes.push_back(x);
        }
    }

    int64_t phi_P = coprimes.size();
    std::vector<uint64_t> jump_table;
    std::vector<int64_t> lookup_table(P + 1, 0);
    std::vector<uint64_t> offset_table(P, 0);

    for (size_t i = 0; i < coprimes.size(); ++i) {
        uint64_t r = coprimes[i];
        lookup_table[r] = i + 1;
        if (i < coprimes.size() - 1) {
            jump_table.push_back(coprimes[i+1] - coprimes[i]);
        } else {
            jump_table.push_back((P + coprimes[0]) - coprimes[i]);
        }
    }

    size_t cp_idx = 0;
    size_t num_cp = coprimes.size();
    for (uint64_t r = 0; r < P; ++r) {
        while (cp_idx < num_cp && coprimes[cp_idx] < r) {
            cp_idx++;
        }
        if (cp_idx < num_cp) {
            offset_table[r] = coprimes[cp_idx] - r;
        } else {
            offset_table[r] = (coprimes[0] + P) - r;
        }
    }

    std::vector<bool> is_coprime(P, false);
    for (uint64_t r = 0; r < P; ++r) {
        if (std::gcd(r, P) == 1) {
            is_coprime[r] = true;
        }
    }

    return PrimorialWheel{P, jump_table, lookup_table, offset_table, phi_P, is_coprime};
}

uint64_t get_next_prime_sieved(uint64_t current, const std::vector<bool>& sieve, uint64_t max_limit) {
    uint64_t nxt = current + 1;
    while (nxt <= max_limit) {
        if (sieve[nxt]) {
            return nxt;
        }
        nxt++;
    }
    return max_limit + 1;
}

// --- FASE 2 e FASE 3: RACCOLTA DEI DIVISORI UTILI ---

std::vector<uint64_t> get_smart_divisors(unsigned __int128 n, uint64_t W, uint64_t limit, const std::vector<uint64_t>& modulo_gap) {
    unsigned int num_threads = std::thread::hardware_concurrency();
    if (num_threads == 0) num_threads = 1;

    uint64_t MOD = 510510;
    uint64_t limit_f1 = 2 * W;

    // =========================================================================
    // [FASE 2] Inserimento numeri primi NextPrime fino a 2W nella memoria
    // =========================================================================
    std::cout << "[FASE 2] Generazione tramite NextPrime fino a 2W (" << limit_f1 << ")...\n";

    std::vector<bool> sieve(limit_f1 + 1, true);
    sieve[0] = false; sieve[1] = false;
    for (uint64_t p = 2; p * p <= limit_f1; ++p) {
        if (sieve[p]) {
            for (uint64_t i = p * p; i <= limit_f1; i += p) {
                sieve[i] = false;
            }
        }
    }

    std::vector<uint64_t> divisori_utili;
    uint64_t pr = 1;

    while (true) {
        uint64_t primes_val = get_next_prime_sieved(pr, sieve, limit_f1);
        if (primes_val > limit_f1) {
            break;
        }
        if (primes_val >= 19) {
            divisori_utili.push_back(primes_val);
        }
        pr = primes_val;
    }

    // =========================================================================
    // [FASE 3] Il tuo ciclo originale: n = MOD * c + 19 avanzato via Gaps
    // =========================================================================
    std::cout << "[FASE 3] Viaggio sui passi di gap della ruota fino a Radice (" << limit << ")...\n";

    uint64_t max_c = limit / MOD;
    uint64_t chunks_per_thread = (max_c / num_threads) + 1;

    std::vector<std::vector<uint64_t>> thread_divs(num_threads);
    std::vector<std::thread> threads;

    for (unsigned int t = 0; t < num_threads; ++t) {
        threads.emplace_back([&, t]() {
            uint64_t c_start = t * chunks_per_thread;
            uint64_t c_end = (t == num_threads - 1) ? max_c : (c_start + chunks_per_thread - 1);
            if (c_end > max_c) c_end = max_c;

            for (uint64_t c = c_start; c <= c_end; ++c) {
                // Il tuo identico innesco originale da 19
                uint64_t p_f2 = MOD * c + 19;

                for (uint64_t g : modulo_gap) {
                    if (p_f2 > limit) break;

                    if (p_f2 > limit_f1) {
                        uint64_t r = static_cast<uint64_t>(n % p_f2);
                        if (r % 2 == 0) {
                            if ((p_f2 - r) <= W) {
                                thread_divs[t].push_back(p_f2);
                            }
                        }
                    }
                    p_f2 += g;
                }
            }
        });
    }

    for (auto& th : threads) {
        th.join();
    }

    for (const auto& v : thread_divs) {
        divisori_utili.insert(divisori_utili.end(), v.begin(), v.end());
    }

    return divisori_utili;
}

// --- [FASE 4] MOTORE DI NAVIGAZIONE E SETACCIO DELLA FINESTRA n+W ---

std::vector<unsigned __int128> lrln_parallel_engine(unsigned __int128 n, uint64_t W, const PrimorialWheel& wheel, const std::vector<uint64_t>& divisori_utili) {
    unsigned int num_threads = std::thread::hardware_concurrency();
    if (num_threads == 0) num_threads = 1;

    uint64_t segment_size = W / num_threads;
    std::vector<uint8_t> is_prime_candidate(W + 1, 1);

    std::cout << "[FASE 4] Avvio scrematura finestra su " << num_threads << " thread...\n";

    std::vector<std::thread> engine_threads;

    for (unsigned int t = 0; t < num_threads; ++t) {
        engine_threads.emplace_back([&, t]() {
            uint64_t start_offset = t * segment_size;
            uint64_t end_offset = (t == num_threads - 1) ? W : ((t + 1) * segment_size) - 1;

            uint64_t rem_P = static_cast<uint64_t>((n + start_offset) % wheel.P);
            uint64_t P_val = wheel.P;

            for (uint64_t i = start_offset; i <= end_offset; ++i) {
                if (!wheel.is_coprime[rem_P]) {
                    is_prime_candidate[i] = 0;
                }
                rem_P++;
                if (rem_P == P_val) {
                    rem_P = 0;
                }
            }

            for (uint64_t p : divisori_utili) {
                uint64_t r_start = static_cast<uint64_t>((n + start_offset) % p);
                uint64_t to_next = (r_start == 0) ? 0 : (p - r_start);

                if (static_cast<uint64_t>((n + start_offset + to_next) % 2) == 0) {
                    to_next += p;
                }

                uint64_t idx = start_offset + to_next;
                while (idx <= end_offset) {
                    is_prime_candidate[idx] = 0;
                    idx += 2 * p;
                }
            }
        });
    }

    for (auto& th : engine_threads) {
        th.join();
    }

    std::vector<unsigned __int128> primes;
    for (uint64_t i = 0; i <= W; ++i) {
        if (is_prime_candidate[i]) {
            primes.push_back(n + i);
        }
    }
    return primes;
}

// --- [FASE 5] ESPORTAZIONE FILE PRIMES_SUFFIX.TXT ---

void export_primes_suffix(unsigned __int128 n, uint64_t W, const std::vector<unsigned __int128>& primes, const std::string& filename) {
    std::ofstream io(filename);
    if (io.is_open()) {
        io << "#A=" << uint128_to_string(n) << " W=" << W << "\n";
        for (unsigned __int128 p : primes) {
            io << static_cast<uint64_t>(p - n) << "\n";
        }
        std::cout << "[FASE 5] File esportato con successo: " << filename << "\n";
    } else {
        std::cerr << "[ERRORE] Impossibile aprire il file di output.\n";
    }
}

// --- MAIN EXECUTION ---

int main(int argc, char* argv[]) {
    auto start_time = std::chrono::high_resolution_clock::now();

    // Valori di default (se l'utente non scrive nulla sulla riga di comando)
    std::string input_n = "10000000000000000000";
    uint64_t W = 1000000ULL;

    // Controllo se l'utente ha inserito gli argomenti da riga di comando
    if (argc >= 2) {
        input_n = argv[1]; // Il primo argomento dopo il nome del programma è la magnitudo
    }
    if (argc >= 3) {
        W = std::stoull(argv[2]); // Il secondo argomento è l'ampiezza della finestra
    }

    unsigned __int128 n = parse_uint128(input_n);
    uint64_t P_val = 510510ULL;

    uint64_t limit = static_cast<uint64_t>(std::floor(std::sqrt(static_cast<long double>(n + W))));
    std::string output_file = "primes_suffix.txt";

    unsigned int active_threads = std::thread::hardware_concurrency();

    std::cout << "--- LRLN MASTER ENGINE (NATIVE C++ 128-BIT PURE GAP MODE) ---\n";
    std::cout << "n: " << uint128_to_string(n) << " | W: " << W << " | P: " << P_val << "\n";
    std::cout << "Threads rilevati: " << active_threads << "\n\n";

    auto t0 = std::chrono::high_resolution_clock::now();
    std::vector<uint64_t> modulo_gap = generate_modulo_gaps();
    PrimorialWheel wheel = generate_wheel(P_val);
    auto t1 = std::chrono::high_resolution_clock::now();
    std::cout << "Tempo preparazione strutture: "
              << std::chrono::duration_cast<std::chrono::microseconds>(t1 - t0).count() / 1000000.0
              << " secondi.\n";

    t0 = std::chrono::high_resolution_clock::now();
    std::vector<uint64_t> divisori_utili = get_smart_divisors(n, W, limit, modulo_gap);
    t1 = std::chrono::high_resolution_clock::now();
    std::cout << "Tempo selezione divisori (Fase 2 + Fase 3): "
              << std::chrono::duration_cast<std::chrono::microseconds>(t1 - t0).count() / 1000000.0
              << " secondi.\n";
    std::cout << "Divisori utili complessivi in memoria: " << divisori_utili.size() << "\n";

    t0 = std::chrono::high_resolution_clock::now();
    std::vector<unsigned __int128> primes = lrln_parallel_engine(n, W, wheel, divisori_utili);
    t1 = std::chrono::high_resolution_clock::now();
    std::cout << "Tempo scrematura finestra (Fase 4): "
              << std::chrono::duration_cast<std::chrono::microseconds>(t1 - t0).count() / 1000000.0
              << " secondi.\n";

    export_primes_suffix(n, W, primes, output_file);

    std::cout << "\n--- RISULTATI FINALI ---\n";
    std::cout << "Candidati primi trovati nella finestra: " << primes.size() << "\n";
    if (!primes.empty()) {
        std::cout << "Primo offset: " << static_cast<uint64_t>(primes.front() - n) << "\n";
        std::cout << "Ultimo offset: " << static_cast<uint64_t>(primes.back() - n) << "\n";
    }

    auto end_time = std::chrono::high_resolution_clock::now();
    auto total_ms = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count();

    uint64_t minuti = total_ms / 60000;
    uint64_t secondi = (total_ms % 60000) / 1000;
    uint64_t millisecondi = total_ms % 1000;

    std::cout << "\n[TEMPO] Tempo totale di esecuzione -> " << minuti << " min : " << secondi << " sec : " << millisecondi << " ms\n";

    return 0;
}
