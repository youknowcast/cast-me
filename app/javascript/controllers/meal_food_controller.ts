import { Controller } from "@hotwired/stimulus"

/**
 * Meal Food Controller
 * 食べ物をチップとして追加/削除し、meal[food_names][] を送信する
 */
export default class extends Controller {
	static targets = ["chips", "input", "selectModal"]

	declare chipsTarget: HTMLElement
	declare inputTarget: HTMLInputElement
	declare selectModalTarget: HTMLDialogElement
	declare hasSelectModalTarget: boolean

	quickSelect(event: Event) {
		const name = (event.currentTarget as HTMLElement).dataset.foodName
		if (name) this.addFood(name)
	}

	selectFromList(event: Event) {
		const name = (event.currentTarget as HTMLElement).dataset.foodName
		if (name) this.addFood(name)
		this.closeSelect()
	}

	addFromInput() {
		const name = this.inputTarget.value.trim()
		if (name) {
			this.addFood(name)
			this.inputTarget.value = ""
		}
		this.inputTarget.focus()
	}

	removeFood(event: Event) {
		const btn = event.currentTarget as HTMLElement
		btn.closest("[data-food-name]")?.remove()
	}

	openSelect() {
		if (this.hasSelectModalTarget) this.selectModalTarget.showModal()
	}

	closeSelect() {
		if (this.hasSelectModalTarget) this.selectModalTarget.close()
	}

	private addFood(name: string) {
		if (this.existingNames().includes(name)) return

		const chip = document.createElement("span")
		chip.className = "badge badge-lg gap-1"
		chip.dataset.foodName = name

		const hidden = document.createElement("input")
		hidden.type = "hidden"
		hidden.name = "meal[food_names][]"
		hidden.value = name

		const label = document.createElement("span")
		label.textContent = name

		const remove = document.createElement("button")
		remove.type = "button"
		remove.textContent = "✕"
		remove.dataset.action = "meal-food#removeFood"

		chip.append(hidden, label, remove)
		this.chipsTarget.appendChild(chip)
	}

	private existingNames(): string[] {
		return Array.from(this.chipsTarget.querySelectorAll<HTMLElement>("[data-food-name]")).map(
			el => el.dataset.foodName || "",
		)
	}
}
