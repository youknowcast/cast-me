import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static targets = ["modal", "hourWheel", "minuteWheel", "hourValue", "minuteValue"]

	declare readonly modalTarget: HTMLDialogElement
	declare readonly hourWheelTarget: HTMLElement
	declare readonly minuteWheelTarget: HTMLElement
	declare readonly hourValueTarget: HTMLElement
	declare readonly minuteValueTarget: HTMLElement

	private selectedHour = 0
	private selectedMinute = 0
	private currentTrigger: any = null
	private itemHeight = 44 // Height of each wheel item in pixels

	connect() {
		window.addEventListener('timepicker:open', this.open.bind(this) as any)
		this.modalTarget.addEventListener('click', this.handleBackdropClick.bind(this))
	}

	disconnect() {
		window.removeEventListener('timepicker:open', this.open.bind(this) as any)
		this.modalTarget.removeEventListener('click', this.handleBackdropClick.bind(this))
	}

	handleBackdropClick(event: MouseEvent) {
		if (event.target === this.modalTarget) {
			this.confirm()
		}
	}

	open(event: CustomEvent) {
		const { time, trigger } = event.detail
		this.currentTrigger = trigger

		// Parse time if provided
		if (time) {
			const [h, m] = time.split(':').map(Number)
			this.selectedHour = isNaN(h) ? 0 : h
			this.selectedMinute = isNaN(m) ? 0 : m
		} else {
			const now = new Date()
			this.selectedHour = now.getHours()
			this.selectedMinute = now.getMinutes()
		}

		this.renderWheels()
		this.modalTarget.showModal()
		this.scrollToSelected()
	}

	close() {
		this.modalTarget.close()
	}

	confirm() {
		if (this.currentTrigger) {
			const timeStr = `${String(this.selectedHour).padStart(2, '0')}:${String(this.selectedMinute).padStart(2, '0')}`
			window.dispatchEvent(new CustomEvent('timepicker:confirmed', {
				detail: {
					time: timeStr,
					trigger: this.currentTrigger
				}
			}))
		}
		this.close()
	}

	renderWheels() {
		// Clear existing content
		this.hourWheelTarget.innerHTML = ''
		this.minuteWheelTarget.innerHTML = ''

		// Create hour items (0-23)
		for (let h = 0; h < 24; h++) {
			const item = this.createWheelItem(h, 'hour')
			this.hourWheelTarget.appendChild(item)
		}

		// Create minute items (0-59)
		for (let m = 0; m < 60; m++) {
			const item = this.createWheelItem(m, 'minute')
			this.minuteWheelTarget.appendChild(item)
		}

		this.updateDisplay()
	}

	createWheelItem(value: number, type: 'hour' | 'minute'): HTMLElement {
		const item = document.createElement('button')
		item.type = 'button'
		item.className = 'w-full h-11 flex items-center justify-center text-xl font-medium text-gray-400 transition-all duration-150 touch-manipulation'
		item.textContent = String(value).padStart(2, '0')
		item.dataset.value = String(value)

		item.addEventListener('click', () => {
			if (type === 'hour') {
				this.selectedHour = value
				this.scrollHourTo(value)
			} else {
				this.selectedMinute = value
				this.scrollMinuteTo(value)
			}
			this.updateDisplay()
		})

		return item
	}

	scrollToSelected() {
		requestAnimationFrame(() => {
			this.scrollHourTo(this.selectedHour, false)
			this.scrollMinuteTo(this.selectedMinute, false)
		})
	}

	scrollHourTo(hour: number, smooth = true) {
		const container = this.hourWheelTarget.parentElement
		if (container) {
			const scrollTop = hour * this.itemHeight
			container.scrollTo({
				top: scrollTop,
				behavior: smooth ? 'smooth' : 'instant' as any
			})
		}
	}

	scrollMinuteTo(minute: number, smooth = true) {
		const container = this.minuteWheelTarget.parentElement
		if (container) {
			const scrollTop = minute * this.itemHeight
			container.scrollTo({
				top: scrollTop,
				behavior: smooth ? 'smooth' : 'instant' as any
			})
		}
	}

	onHourScroll(event: Event) {
		const container = event.target as HTMLElement
		const newHour = Math.round(container.scrollTop / this.itemHeight)
		if (newHour !== this.selectedHour && newHour >= 0 && newHour < 24) {
			this.selectedHour = newHour
			this.updateDisplay()
		}
	}

	onMinuteScroll(event: Event) {
		const container = event.target as HTMLElement
		const newMinute = Math.round(container.scrollTop / this.itemHeight)
		if (newMinute !== this.selectedMinute && newMinute >= 0 && newMinute < 60) {
			this.selectedMinute = newMinute
			this.updateDisplay()
		}
	}

	// Snap to nearest item after scroll ends
	onHourScrollEnd() {
		this.scrollHourTo(this.selectedHour)
	}

	onMinuteScrollEnd() {
		this.scrollMinuteTo(this.selectedMinute)
	}

	updateDisplay() {
		this.hourValueTarget.textContent = String(this.selectedHour).padStart(2, '0')
		this.minuteValueTarget.textContent = String(this.selectedMinute).padStart(2, '0')

		// Update visual styles for hour wheel
		this.hourWheelTarget.querySelectorAll('button').forEach((btn, index) => {
			if (index === this.selectedHour) {
				btn.classList.remove('text-gray-400')
				btn.classList.add('text-gray-900', 'font-bold', 'text-2xl')
			} else {
				btn.classList.remove('text-gray-900', 'font-bold', 'text-2xl')
				btn.classList.add('text-gray-400')
			}
		})

		// Update visual styles for minute wheel
		this.minuteWheelTarget.querySelectorAll('button').forEach((btn, index) => {
			if (index === this.selectedMinute) {
				btn.classList.remove('text-gray-400')
				btn.classList.add('text-gray-900', 'font-bold', 'text-2xl')
			} else {
				btn.classList.remove('text-gray-900', 'font-bold', 'text-2xl')
				btn.classList.add('text-gray-400')
			}
		})
	}
}
