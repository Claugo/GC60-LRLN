# luglio 2026 - Test LRLN Sieve con Modulo P = 510510 e logica NextPrime
print("\033c")
# luglio 2026 - Test LRLN Sieve con Modulo P = 510510 e logica Gap Puri
using BenchmarkTools
using Base.Threads

# --- STRUTTURE DATI ---

struct PrimorialWheel
    P::UInt64
    jump_table::Vector{UInt64}
    lookup_table::Vector{Int64}
    offset_table::Vector{UInt64}
    phi_P::Int64
    is_coprime::Vector{Bool} 
end

# --- FASE 1: STRUTTURE DELLA RUOTA E GENERAZIONE DEI GAP ESTESI ---

function generate_modulo_gaps()
    modulo_gap = UInt64[]
    precedente = UInt64(19)

    # Estendiamo la ricerca fino a 510510 + 19 per includere i passi dei residui iniziali
    for i in UInt64(23):UInt64(2):(UInt64(510510) + 19)
        if i % 3 != 0 && i % 5 != 0 && i % 7 != 0 &&
           i % 11 != 0 && i % 13 != 0 && i % 17 != 0
            push!(modulo_gap, i - precedente)
            precedente = i
        end
    end
    return modulo_gap
end

function generate_wheel(P::UInt64)
    println("[FASE 1] Generazione tabelle ruota per P = $P...")
    coprimes = UInt64[]
    for x in 1:P
        if gcd(x, P) == 1
            push!(coprimes, x)
        end
    end
    phi_P = length(coprimes)
    jump_table = UInt64[]
    lookup_table = zeros(Int64, P + 1)
    offset_table = zeros(UInt64, P + 1)

    for i in 1:phi_P
        r = coprimes[i]
        lookup_table[r] = i
        if i < phi_P
            push!(jump_table, coprimes[i+1] - coprimes[i])
        else
            push!(jump_table, (P + coprimes[1]) - coprimes[i])
        end
    end

    cp_idx = 1
    num_cp = length(coprimes)
    for r in 0:(P-1)
        while cp_idx <= num_cp && coprimes[cp_idx] < r
            cp_idx += 1
        end
        if cp_idx <= num_cp
            offset_table[r+1] = coprimes[cp_idx] - r
        else
            offset_table[r+1] = (coprimes[1] + P) - r
        end
    end

    is_coprime = zeros(Bool, P)
    for r in 0:(P-1)
        if gcd(r, P) == 1
            is_coprime[r + 1] = true
        end
    end

    return PrimorialWheel(P, jump_table, lookup_table, offset_table, phi_P, is_coprime)
end

function get_next_prime_sieved(current::UInt64, sieve::Vector{Bool}, max_limit::UInt64)
    nxt = current + 1
    while nxt <= max_limit
        if sieve[nxt]
            return nxt
        end
        nxt += 1
    end
    return max_limit + 1
end

# --- FASE 2 e FASE 3: RACCOLTA DEI DIVISORI UTILI CON LOGICA PURA GAP ---

function get_smart_divisors(n::UInt128, W::UInt64, limit::UInt64, modulo_gap::Vector{UInt64})
    num_threads = Threads.nthreads()
    MOD = UInt64(510510)
    limit_f1 = 2 * W

    # =========================================================================
    # [FASE 2] Inserimento numeri primi NextPrime fino a 2W nella memoria
    # =========================================================================
    println("[FASE 2] Generazione tramite NextPrime fino a 2W ($limit_f1)...")
    
    sieve = fill(true, limit_f1)
    sieve[1] = false
    for p in 2:Int(floor(sqrt(limit_f1)))
        if sieve[p]
            for i in (p*p):p:limit_f1
                sieve[i] = false
            end
        end
    end

    divisori_utili = UInt64[]
    pr = UInt64(1)
    
    while true
        primes_val = get_next_prime_sieved(pr, sieve, UInt64(limit_f1))
        if primes_val > limit_f1
            break
        end
        if primes_val >= 19
            push!(divisori_utili, primes_val)
        end
        pr = primes_val
    end

    # =========================================================================
    # [FASE 3] Viaggio sulla Ruota (19 + gaps...) e verifica LRLN parallela
    # =========================================================================
    println("[FASE 3] Viaggio sui passi di gap della ruota fino a Radice ($limit)...")
    
    max_c = div(limit, MOD)
    chunks_per_thread = div(max_c, num_threads) + 1
    
    thread_divs = [UInt64[] for _ in 1:num_threads]
    
    let n=n, W=W, limit=limit, MOD=MOD, limit_f1=limit_f1, modulo_gap=modulo_gap, thread_divs=thread_divs, chunks_per_thread=chunks_per_thread, max_c=max_c
        Threads.@threads for t in 1:num_threads
            c_start = (t - 1) * chunks_per_thread
            c_end = t * chunks_per_thread - 1
            if c_end > max_c
                c_end = max_c
            end
            
            for c in c_start:c_end
                # Il tuo innesco originale da 19 avanzato solo tramite addizioni di gap
                p_f2 = MOD * c + 19
                
                for g in modulo_gap
                    if p_f2 > limit
                        break
                    end
                    
                    if p_f2 > limit_f1
                        r = UInt64(n % p_f2)
                        if r % 2 == 0 
                            if (p_f2 - r) <= W
                                @inbounds push!(thread_divs[t], p_f2) 
                            end
                        end
                    end
                    p_f2 += g
                end
            end
        end
    end
    
    for t in 1:num_threads
        append!(divisori_utili, thread_divs[t])
    end
    
    return divisori_utili
end

# --- [FASE 4] MOTORE DI NAVIGAZIONE E SETACCIO DELLA FINESTRA n+W ---

function lrln_parallel_engine(n::UInt128, W::UInt64, wheel::PrimorialWheel, divisori_utili::Vector{UInt64})
    num_threads = Threads.nthreads()
    segment_size = div(W, num_threads)
    is_prime_candidate = fill(true, W + 1)

    println("[FASE 4] Avvio scrematura finestra su $num_threads thread...")

    let n=n, W=W, wheel=wheel, divisori_utili=divisori_utili, is_prime_candidate=is_prime_candidate, segment_size=segment_size, num_threads=num_threads
        Threads.@threads for t in 1:num_threads
            start_offset = (t - 1) * segment_size
            end_offset = (t == num_threads) ? W : (t * segment_size) - 1
            
            rem_P = UInt64((n + start_offset) % wheel.P)
            P_val = wheel.P
            
            for i in start_offset:end_offset
                if !wheel.is_coprime[rem_P + 1]
                    @inbounds is_prime_candidate[i+1] = false
                end
                rem_P += 1
                if rem_P == P_val
                    rem_P = 0
                end
            end

            for p in divisori_utili
                r_start = UInt64((n + start_offset) % p)
                to_next = (r_start == 0) ? UInt64(0) : (p - r_start)
                
                if (n + start_offset + to_next) % 2 == 0
                    to_next += p
                end
                
                idx = start_offset + to_next
                while idx <= end_offset
                    @inbounds is_prime_candidate[idx+1] = false
                    idx += 2p 
                end
            end
        end
    end

    primes = UInt128[]
    for i in 1:W+1
        if is_prime_candidate[i]
            push!(primes, n + i - 1)
        end
    end
    return primes
end

# --- [FASE 5] ESPORTAZIONE FILE PRIMES_SUFFIX.TXT ---

function export_primes_suffix(n::UInt128, W::UInt64, primes::Vector{UInt128}, filename::String)
    open(filename, "w") do io
        println(io, "#A=$n W=$W")
        for p in primes
            offset = UInt64(p - n)
            println(io, offset)
        end
    end
    println("[FASE 5] File esportato con successo: $filename")
end

# --- MAIN EXECUTION ---

function main()
    start_time = time_ns()

    # Puoi impostare qui la magnitudo desiderata (es. 10^19 o 10^21) senza problemi di overflow
    n = parse(UInt128, "10000000000000000000")      
    W = UInt64(1_000_000)  
    P_val = UInt64(510510)  
    limit = UInt64(floor(sqrt(n + W)))
    output_file = "primes_suffix.txt"

    println("--- LRLN MASTER ENGINE (NATIVE JULIA 128-BIT PURE GAP MODE) ---")
    println("n: $n | W: $W | P: $P_val")
    println("Threads attivi in Julia: $(Threads.nthreads())\n")

    modulo_gap = generate_modulo_gaps()
    wheel = generate_wheel(P_val)
    
    println("\n[INFO] Avvio raccolta divisori utili...")
    @time divisori_utili = get_smart_divisors(n, W, limit, modulo_gap)
    println("Divisori utili complessivi in memoria: $(length(divisori_utili))")

    println("\n[INFO] Esecuzione Setaccio Finestra...")
    @time primes = lrln_parallel_engine(n, W, wheel, divisori_utili)

    println("\n[INFO] Esportazione in corso...")
    @time export_primes_suffix(n, W, primes, output_file)

    println("\n--- RISULTATI FINALI ---")
    println("Candidati primi trovati nella finestra: $(length(primes))")
    if length(primes) > 0
        println("Primo offset: $(UInt64(primes[1] - n))")
        println("Ultimo offset: $(UInt64(primes[end] - n))")
    end

    end_time = time_ns()
    total_ms = div(end_time - start_time, 1_000_000)
    
    minuti = div(total_ms, 60000)
    secondi = div(total_ms % 60000, 1000)
    millisecondi = total_ms % 1000

    println("\n[TEMPO] Tempo totale di esecuzione -> $minuti min : $secondi sec : $millisecondi ms")
end

main();