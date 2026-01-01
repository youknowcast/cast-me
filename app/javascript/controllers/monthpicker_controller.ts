import { BaseDrumPickerController } from "../lib/base_drum_picker_controller"

export default class extends BaseDrumPickerController {
	static targets = ["modal", "yearWheel", "monthWheel", "yearValue", "monthValue"]

	declare readonly yearWheelTarget: HTMLElement
	declare readonly monthWheelTarget: HTMLElement
	declare readonly yearValueTarget: HTMLElement
	declare readonly monthValueTarget: HTMLElement

	private selectedYear = new Date().getFullYear()
	private selectedMonth = new Date().getMonth() + 1
	private baseUrl = ""

	get eventPrefix() {
		return 'monthpicker'
	}

	onOpen(detail: any) {
		const { date, baseUrl } = detail
		this.baseUrl = baseUrl || ''

		// Parse date if provided (YYYY-MM-DD format)
		if (date) {
			const parsed = new Date(date)
			if (!isNaN(parsed.getTime())) {
				this.selectedYear = parsed.getFullYear()
				this.selectedMonth = parsed.getMonth() + 1
			}
		}

		this.renderWheels()
		this.scrollToSelected()
	}

	onConfirm() {
		if (this.baseUrl) {
			const dateStr = `${this.selectedYear}-${String(this.selectedMonth).padStart(2, '0')}-01`
			const url = new URL(this.baseUrl, window.location.origin)
			url.searchParams.set('date', dateStr)
			window.location.href = url.toString()
		}
		return null // No event dispatch needed, we're navigating
	}

	renderWheels() {
		this.yearWheelTarget.innerHTML = ''
		this.monthWheelTarget.innerHTML = ''

		// Create year items (current year -5 to +5)
		const currentYear = new Date().getFullYear()
		for (let y = currentYear - 5; y <= currentYear + 5; y++) {
			const item = this.createWheelItem(y, String(y) + '年', (value) => {
				this.selectedYear = value
				this.scrollYearTo(value)
				this.updateDisplay()
			})
			this.yearWheelTarget.appendChild(item)
		}

		// Create month items (1-12)
		for (let m = 1; m <= 12; m++) {
			const item = this.createWheelItem(m, String(m) + '月', (value) => {
				this.selectedMonth = value
				this.scrollMonthTo(value)
				this.updateDisplay()
			})
			this.monthWheelTarget.appendChild(item)
		}

		this.updateDisplay()
	}

	scrollToSelected() {
		requestAnimationFrame(() => {
			this.scrollYearTo(this.selectedYear, false)
			this.scrollMonthTo(this.selectedMonth, false)
		})
	}

	private scrollYearTo(year: number, smooth = true) {
		const currentYear = new Date().getFullYear()
		const index = year - (currentYear - 5)
		this.scrollWheelTo(this.yearWheelTarget.parentElement, index, smooth)
	}

	private scrollMonthTo(month: number, smooth = true) {
		this.scrollWheelTo(this.monthWheelTarget.parentElement, month - 1, smooth)
	}

	onYearScroll(event: Event) {
		const container = event.target as HTMLElement
		const currentYear = new Date().getFullYear()
		const index = this.getIndexFromScroll(container)
		const newYear = (currentYear - 5) + index
		if (newYear !== this.selectedYear && newYear >= currentYear - 5 && newYear <= currentYear + 5) {
			this.selectedYear = newYear
			this.updateDisplay()
		}
	}

	onMonthScroll(event: Event) {
		const container = event.target as HTMLElement
		const newMonth = this.getIndexFromScroll(container) + 1
		if (newMonth !== this.selectedMonth && newMonth >= 1 && newMonth <= 12) {
			this.selectedMonth = newMonth
			this.updateDisplay()
		}
	}

	onYearScrollEnd() {
		this.scrollYearTo(this.selectedYear)
	}

	onMonthScrollEnd() {
		this.scrollMonthTo(this.selectedMonth)
	}

	private updateDisplay() {
		this.yearValueTarget.textContent = String(this.selectedYear)
		this.monthValueTarget.textContent = String(this.selectedMonth).padStart(2, '0')

		this.updateWheelHighlight(this.yearWheelTarget, this.selectedYear)
		this.updateWheelHighlight(this.monthWheelTarget, this.selectedMonth)
	}
}
