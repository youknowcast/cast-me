import { BaseDrumPickerController } from "../lib/base_drum_picker_controller"

export default class extends BaseDrumPickerController {
	static targets = ["modal", "hourWheel", "minuteWheel", "hourValue", "minuteValue"]

	declare readonly hourWheelTarget: HTMLElement
	declare readonly minuteWheelTarget: HTMLElement
	declare readonly hourValueTarget: HTMLElement
	declare readonly minuteValueTarget: HTMLElement

	private selectedHour = 0
	private selectedMinute = 0

	get eventPrefix() {
		return 'timepicker'
	}

	onOpen(detail: any) {
		const { time } = detail

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
		this.scrollToSelected()
	}

	onConfirm() {
		const timeStr = `${String(this.selectedHour).padStart(2, '0')}:${String(this.selectedMinute).padStart(2, '0')}`
		return { time: timeStr }
	}

	renderWheels() {
		// Clear existing content
		this.hourWheelTarget.innerHTML = ''
		this.minuteWheelTarget.innerHTML = ''

		// Create hour items (0-23)
		for (let h = 0; h < 24; h++) {
			const item = this.createWheelItem(h, String(h).padStart(2, '0'), (value) => {
				this.selectedHour = value
				this.scrollHourTo(value)
				this.updateDisplay()
			})
			this.hourWheelTarget.appendChild(item)
		}

		// Create minute items (0-59)
		for (let m = 0; m < 60; m++) {
			const item = this.createWheelItem(m, String(m).padStart(2, '0'), (value) => {
				this.selectedMinute = value
				this.scrollMinuteTo(value)
				this.updateDisplay()
			})
			this.minuteWheelTarget.appendChild(item)
		}

		this.updateDisplay()
	}

	scrollToSelected() {
		requestAnimationFrame(() => {
			this.scrollHourTo(this.selectedHour, false)
			this.scrollMinuteTo(this.selectedMinute, false)
		})
	}

	private scrollHourTo(hour: number, smooth = true) {
		this.scrollWheelTo(this.hourWheelTarget.parentElement, hour, smooth)
	}

	private scrollMinuteTo(minute: number, smooth = true) {
		this.scrollWheelTo(this.minuteWheelTarget.parentElement, minute, smooth)
	}

	onHourScroll(event: Event) {
		const container = event.target as HTMLElement
		const newHour = this.getIndexFromScroll(container)
		if (newHour !== this.selectedHour && newHour >= 0 && newHour < 24) {
			this.selectedHour = newHour
			this.updateDisplay()
		}
	}

	onMinuteScroll(event: Event) {
		const container = event.target as HTMLElement
		const newMinute = this.getIndexFromScroll(container)
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

	private updateDisplay() {
		this.hourValueTarget.textContent = String(this.selectedHour).padStart(2, '0')
		this.minuteValueTarget.textContent = String(this.selectedMinute).padStart(2, '0')

		this.updateWheelHighlight(this.hourWheelTarget, this.selectedHour)
		this.updateWheelHighlight(this.minuteWheelTarget, this.selectedMinute)
	}
}
