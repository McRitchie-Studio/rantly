// The demo composer: counts toward Rantly's 140-character floor and, when the
// button is pressed, says plainly that nothing was posted. It never sends
// anything anywhere; there is no form and no request.
export function startComposers(root = document) {
  root.querySelectorAll("[data-composer]").forEach(setUp)
}

function setUp(composer) {
  const min = Number(composer.dataset.min) || 140
  const input = composer.querySelector("[data-composer-input]")
  const count = composer.querySelector("[data-composer-count]")
  const submit = composer.querySelector("[data-composer-submit]")
  const note = composer.querySelector("[data-composer-note]")
  if (!input || !count || !submit || !note) return

  const render = () => {
    const length = input.value.trim().length
    const short = min - length
    if (short > 0) {
      count.textContent = `${short} ${short === 1 ? "character" : "characters"} to go`
      count.classList.remove("is-ready")
      submit.disabled = true
    } else {
      count.textContent = `${length} characters. That's a rant.`
      count.classList.add("is-ready")
      submit.disabled = false
    }
  }

  input.addEventListener("input", () => {
    note.classList.remove("is-shouting")
    render()
  })

  submit.addEventListener("click", () => {
    note.textContent = "Demo only: your rant was not posted or saved. Rantly's showcase has no accounts, but that felt good, didn't it?"
    note.classList.add("is-shouting")
  })

  render()
}
