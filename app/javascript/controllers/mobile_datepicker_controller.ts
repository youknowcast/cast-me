import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static targets = ["input", "triggerText", "modal", "picker"]
	static values = { id: String }

	declare readonly inputTarget: HTMLInputElement
	declare readonly triggerTextTarget: HTMLElement
	declare readonly modalTarget: HTMLDialogElement
	declare readonly pickerTarget: HTMLInputElement

	connect() {
		this.updateTriggerText()
	}

	open() {
		if (this.modalTarget) {
			this.modalTarget.showModal()
		}
	}

	close() {
		if (this.modalTarget) {
			this.modalTarget.close()
		}
	}

	update(event: Event) {
		const input = event.target as HTMLInputElement
		this.inputTarget.value = input.value
		this.updateTriggerText()
	}

	private updateTriggerText() {
		if (this.inputTarget.value) {
			const date = new Date(this.inputTarget.value)
			if (!isNaN(date.getTime())) {
				const year = date.getFullYear()
				const month = String(date.getMonth() + 1).padStart(2, '0')
				const day = String(date.getDate()).padStart(2, '0')
				this.triggerTextTarget.textContent = `${year}/${month}/${day}`
			}
		}
	}
}
