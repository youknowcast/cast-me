import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static targets = ["input", "triggerText"]

	declare readonly inputTarget: HTMLInputElement
	declare readonly triggerTextTarget: HTMLElement

	connect() {
		window.addEventListener('datepicker:confirmed', this.onConfirmed.bind(this) as any)
		this.updateTriggerText()
	}

	disconnect() {
		window.removeEventListener('datepicker:confirmed', this.onConfirmed.bind(this) as any)
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
