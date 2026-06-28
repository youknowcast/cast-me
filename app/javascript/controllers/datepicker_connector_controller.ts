import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static targets = ["input", "triggerText"]

	declare readonly inputTarget: HTMLInputElement
	declare readonly triggerTextTarget: HTMLElement

	private confirmedHandler = this.onConfirmed.bind(this) as EventListener

	connect() {
		window.addEventListener('datepicker:confirmed', this.confirmedHandler)
		this.updateTriggerText()
	}

	disconnect() {
		window.removeEventListener('datepicker:confirmed', this.confirmedHandler)
	}

	open() {
		window.dispatchEvent(new CustomEvent('datepicker:open', {
			detail: {
				date: this.inputTarget.value,
				trigger: this.element
			}
		}))
	}

	onConfirmed(event: CustomEvent) {
		const { date, trigger } = event.detail
		// 自分自身が呼び出し元であるかチェック
		if (trigger === this.element) {
			this.inputTarget.value = date
			this.updateTriggerText()

			// changeイベントを発火させてTurboやStimulusの他の連携を動かす
			this.inputTarget.dispatchEvent(new Event('change', { bubbles: true }))
		}
	}

	private updateTriggerText() {
		// Value is YYYY-MM-DD; format by string substitution to avoid timezone-shifted Date parsing
		if (this.inputTarget.value) {
			this.triggerTextTarget.textContent = this.inputTarget.value.replace(/-/g, '/')
		}
	}
}
