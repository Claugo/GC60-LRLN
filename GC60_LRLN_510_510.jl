# luglio 2026 - Test LRLN Sieve con Modulo P = 510510 e logica NextPrime
print("\033c")
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

# --- 1. PRE-COMPUTAZIONE DELLA RUOTA (WHEEL) ---

function generate_wheel(P::UInt64)
    println("⚙️ Generazione tabelle ruota per P = $P...")
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

# --- FUNZIONE DI APPOGGIO PER IL TUO NEXTPRIME ---
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

# --- 2. SELEZIONE SMART DIVISORI (CON LOGICA NEXTPRIME + BLOCCO PARALLELO BLINDATO) ---

function get_smart_divisors(n::UInt64, W::UInt64, limit::UInt64, wheel::PrimorialWheel)
    num_threads = Threads.nthreads()
    P = wheel.P
    is_coprime = wheel.is_coprime

    # =========================================================================
    # FASE 1: La tua logica "NextPrime" fino a 2*W
    # =========================================================================
    limit_f1 = 2 * W
    println("🌱 Fase 1: Generazione tramite NextPrime fino a 2W ($limit_f1)...")
    
    # Prepariamo un setaccio di supporto in background per far girare il tuo nextprime a O(1)
    sieve = fill(true, limit_f1)
    sieve[1] = false
    for p in 2:Int(floor(sqrt(limit_f1)))
        if sieve[p]
            for i in (p*p):p:limit_f1
                sieve[i] = false
            end
        end
    end

    numeri_utili = UInt64[]
    pr = UInt64(1)
    
    # Il tuo ciclo While originale tradotto fedelmente ed efficientemente
    while true
        primes_val = get_next_prime_sieved(pr, sieve, limit_f1)
        if primes_val > limit_f1
            break
        end
        # Saltiamo i primi 7 piccoli primi (2,3,5,7,11,13,17) già gestiti dal Sub-Task A della ruota
        if primes_val >= 19
            push!(numeri_utili, primes_val)
        end
        pr = primes_val
    end

    # =========================================================================
    # FASE 2: Selezione oltre 2*W con la tua legge geometrica (Blindata contro i bug di Julia)
    # =========================================================================
    r_start = limit_f1 + 1
    if r_start % 2 == 0
        r_start += 1
    end
    r_end = limit

    if r_start > r_end
        return numeri_utili
    end

    println("🔍 Fase 2: Setaccio parallelo oltre 2W fino a Radice ($r_end)...")
    total_elements = div(r_end - r_start, 2) + 1
    chunk_size = div(total_elements, num_threads)
    
    thread_divs = [UInt64[] for _ in 1:num_threads]
    
    # Il blocco 'let' impedisce a Julia di allocare memoria a vuoto sulle variabili esterne
    let n=n, W=W, P=P, is_coprime=is_coprime, thread_divs=thread_divs, chunk_size=chunk_size, r_start=r_start, r_end=r_end, num_threads=num_threads
        Threads.@threads for t in 1:num_threads
            t_start = r_start + (t - 1) * chunk_size * 2
            t_end = (t == num_threads) ? r_end : t_start + (chunk_size * 2) - 2
            
            # Nota fondamentale: Usiamo UInt64(2) come passo per non confondere la CPU
            for p_f2 in t_start:UInt64(2):t_end
                rem_P = p_f2 % P
                if !is_coprime[rem_P + 1]
                    continue 
                end
                
                r = n % p_f2
                if r % 2 == 0 
                    if (p_f2 - r) <= W
                        @inbounds push!(thread_divs[t], p_f2) 
                    end
                end
            end
        end
    end
    
    # Unione finale delle due liste
    smart_divs = UInt64[]
    size_total = length(numeri_utili) + sum(length(v) for v in thread_divs)
    sizehint!(smart_divs, size_total)
    
    append!(smart_divs, numeri_utili) 
    for t in 1:num_threads
        append!(smart_divs, thread_divs[t])
    end
    
    return smart_divs
end

# --- 3. MOTORE DI NAVIGAZIONE E SETACCIO PARALLELO ---

function lrln_parallel_engine(n::UInt64, W::UInt64, wheel::PrimorialWheel, smart_divs::Vector{UInt64})
    num_threads = Threads.nthreads()
    segment_size = div(W, num_threads)
    is_prime_candidate = fill(true, W + 1)

    println("🚀 Avvio Engine su $num_threads thread...")

    let n=n, W=W, wheel=wheel, smart_divs=smart_divs, is_prime_candidate=is_prime_candidate, segment_size=segment_size, num_threads=num_threads
        @threads for t in 1:num_threads
            start_offset = (t - 1) * segment_size
            end_offset = (t == num_threads) ? W : (t * segment_size) - 1
            
            rem_P = (n + start_offset) % wheel.P
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

            for p in smart_divs
                r_start = (n + start_offset) % p
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

    primes = UInt64[]
    for i in 1:W+1
        if is_prime_candidate[i]
            push!(primes, n + i - 1)
        end
    end
    return primes
end

# --- 4. ESPORTAZIONE FORMATO SUFFIX ---

function export_primes_suffix(n::UInt64, W::UInt64, primes::Vector{UInt64}, filename::String)
    open(filename, "w") do io
        println(io, "#A=$n W=$W")
        for p in primes
            offset = p - n
            println(io, offset)
        end
    end
    println("✅ File esportato con successo: $filename")
end

# --- MAIN EXECUTION ---

function main()
    start_time = time_ns()

    n = UInt64(10000000000000000000)      
    W = UInt64(1_000_000)  
    P_val = UInt64(510510)  
    limit = UInt64(floor(sqrt(n + W)))
    output_file = "primes_suffix.txt"

    println("--- LRLN MASTER ENGINE (NATIVE TWO-PHASE MODE) ---")
    println("n: $n | W: $W | P: $P_val")
    println("Threads: $(Threads.nthreads())\n")

    @time wheel = generate_wheel(P_val)
    @time smart_divs = get_smart_divisors(n, W, limit, wheel)
    println("Divisori Smart complessivi in lista: $(length(smart_divs))")

    println("\n🚀 Esecuzione Setaccio Parallelo...")
    @time primes = lrln_parallel_engine(n, W, wheel, smart_divs)

    println("\n💾 Esportazione in formato suffix...\n")
    @time export_primes_suffix(n, W, primes, output_file)

    println("\n--- RISULTATI FINALI ---")
    println("Candidati primi trovati: $(length(primes))")
    if length(primes) > 0
        println("Primo offset: $(primes[1] - n)")
        println("Ultimo offset: $(primes[end] - n)")
    end

    end_time = time_ns()
    total_ms = div(end_time - start_time, 1_000_000)
    
    minuti = div(total_ms, 60000)
    secondi = div(total_ms % 60000, 1000)
    millisecondi = total_ms % 1000

    println("\n⏱️ Tempo totale di esecuzione -> $minuti min : $secondi sec : $millisecondi ms")
end

main();