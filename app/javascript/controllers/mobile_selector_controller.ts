import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static targets = ["input", "triggerText", "modal", "optionCheck"]
	static values = { id: String }

	declare readonly inputTarget: HTMLInputElement
	declare readonly triggerTextTarget: HTMLElement
	declare readonly modalTarget: HTMLDialogElement
	declare readonly optionCheckTargets: HTMLElement[]

	connect() {
		this.updateChecks()
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

	select(event: CustomEvent & { params: { value: string, text: string } }) {
		const { value, text } = event.params
		this.inputTarget.value = value
		this.triggerTextTarget.textContent = text

		this.updateChecks()
		this.close()

		// Dispatch change event to the hidden input so other listeners can react
		this.inputTarget.dispatchEvent(new Event('change', { bubbles: true }))
	}

	private updateChecks() {
		const currentValue = this.inputTarget.value
		this.optionCheckTargets.forEach(target => {
			const value = target.dataset.value
			if (value === currentValue) {
				target.classList.remove('opacity-0')
				target.classList.add('text-primary')
			} else {
				target.classList.remove('text-primary')
				target.classList.add('opacity-0')
			}
		})
	}
}
