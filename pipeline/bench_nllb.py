import time
import torch
import nllb_translator as n

TEXTE = "Bonjour, comment allez-vous ce matin ?"

tok, model = n._charger_modele()
tok.src_lang = "fra_Latn"
inputs = tok(TEXTE, return_tensors="pt")
bos = tok.convert_tokens_to_ids("yor_Latn")


def run(threads, beams):
    torch.set_num_threads(threads)
    t0 = time.time()
    with torch.no_grad():
        model.generate(
            **inputs,
            forced_bos_token_id=bos,
            max_new_tokens=56,
            num_beams=beams,
        )
    return time.time() - t0


run(2, 1)  # échauffement, non compté

for threads, beams in [(2, 1), (4, 1), (2, 4), (4, 4)]:
    durees = [run(threads, beams) for _ in range(3)]
    print(
        f"threads={threads} beams={beams} : "
        + " / ".join(f"{d:.1f}s" for d in durees)
    )