import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static targets = ["inputs", "triggerText", "datesText"]

	declare readonly inputsTarget: HTMLElement
	declare readonly triggerTextTarget: HTMLElement
	declare readonly datesTextTarget: HTMLElement

	private confirmedHandler = this.onConfirmed.bind(this) as EventListener

	connect() {
		window.addEventListener('datepicker:confirmed', this.confirmedHandler)
		this.updateDisplay()
	}

	disconnect() {
		window.removeEventListener('datepicker:confirmed', this.confirmedHandler)
	}

	open() {
		window.dispatchEvent(new CustomEvent('datepicker:open', {
			detail: {
				dates: this.dates,
				multiple: true,
				trigger: this.element
			}
		}))
	}

	private onConfirmed(event: Event) {
		const { dates, trigger } = (event as CustomEvent).detail
		if (trigger !== this.element || !Array.isArray(dates) || dates.length === 0) return

		this.inputsTarget.replaceChildren(...dates.map((date: string) => this.hiddenInput(date)))
		this.updateDisplay()
	}

	private hiddenInput(date: string) {
		const input = document.createElement('input')
		input.type = 'hidden'
		input.name = 'plan[dates][]'
		input.value = date
		return input
	}

	private get dates() {
		return Array.from(this.inputsTarget.querySelectorAll<HTMLInputElement>('input[name="plan[dates][]"]'))
			.map(input => input.value)
			.filter(Boolean)
	}

	private updateDisplay() {
		const dates = this.dates.sort()
		this.triggerTextTarget.textContent = dates.length === 1 ? this.formatDate(dates[0]) : `${dates.length}日選択`
		this.datesTextTarget.textContent = dates.map(date => this.formatDate(date)).join('、')
	}

	private formatDate(date: string) {
		return date.replace(/-/g, '/')
	}
}
