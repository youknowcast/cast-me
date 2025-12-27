import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static targets = ["input", "triggerText"]

	declare readonly inputTarget: HTMLInputElement
	declare readonly triggerTextTarget: HTMLElement

	connect() {
		window.addEventListener('timepicker:confirmed', this.onConfirmed.bind(this) as any)
		this.updateTriggerText()
	}

	disconnect() {
		window.removeEventListener('timepicker:confirmed', this.onConfirmed.bind(this) as any)
	}

	open() {
		window.dispatchEvent(new CustomEvent('timepicker:open', {
			detail: {
				time: this.inputTarget.value,
				trigger: this.element
			}
		}))
	}

	onConfirmed(event: CustomEvent) {
		const { time, trigger } = event.detail
		// Check if this instance triggered the picker
		if (trigger === this.element) {
			this.inputTarget.value = time
			this.updateTriggerText()

			// Dispatch change event for other listeners
			this.inputTarget.dispatchEvent(new Event('change', { bubbles: true }))
		}
	}

	private updateTriggerText() {
		if (this.inputTarget.value) {
			this.triggerTextTarget.textContent = this.inputTarget.value
		} else {
			this.triggerTextTarget.textContent = '--:--'
		}
	}
}
