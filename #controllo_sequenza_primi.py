from sympy import nextprime, divisors
import os

# --- CONFIGURAZIONE ---
path = "primes_suffix.txt"
nome_file = os.path.basename(path)
def verifica_sequenza_rigorosa(filepath):
    primi = []
    base_A = None
    
    # 1. Lettura file
    with open(filepath, "r") as file:
        for riga in file:
            c = riga.strip()
            if not c: continue
            if c.startswith("#"):
                if "A=" in c:
                    base_A = int(c.split("A=")[1].split()[0])
            else:
                primi.append(int(c))
    
    if base_A is None:
        print("Errore: Metadati A= non trovati.")
        return

    # Ricostruiamo i numeri assoluti
    valori = sorted([base_A + s for s in primi])
    
    # 2. Inizio verifica rigorosa
    # Partiamo dal primo numero trovato nella lista
    corrente = valori[0]
    
    print(f"Inizio verifica rigorosa da: {corrente}")
    print(f"Totale candidati da testare: {len(valori)}")

    for i in range(1, len(valori)):
        # Calcoliamo quale DOVREBBE essere il prossimo primo
        prossimo_atteso = nextprime(corrente)
        
        # Confrontiamo con il valore successivo nella tua lista
        if valori[i] != prossimo_atteso:
            print(f"!!! ERRORE SEQUENZA !!!")
            print(f"Precedente: {corrente}")
            print(f"Trovato in lista: {valori[i]}")
            print(f"Atteso da nextprime: {prossimo_atteso}")
            return # Ci fermiamo al primo errore
        
        # Aggiorniamo 'corrente' e proseguiamo
        corrente = valori[i]
        
    print(f"Successo! Tutti i {len(valori)} numeri nella finestra {nome_file} formano una sequenza perfetta di primi.")
    print(f"Questo test viene effettuato con la funzione nextprime di Sympy su Python")
    print(f"Il test prende il primo numero del file e comincia a generare primi con nextprime")
    print(f"e confronta la sequenza generata dal programma LRLN_sieve")

verifica_sequenza_rigorosa(path)