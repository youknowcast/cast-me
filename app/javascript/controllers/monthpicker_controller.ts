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
			return null
		}
		return { year: this.selectedYear, month: this.selectedMonth }
	}

	renderWheels() {
		this.yearWheelTarget.innerHTML = ''
		this.monthWheelTarget.innerHTML = ''

		// Create year items (1980 to current year +5 for flexibility)
		const currentYear = new Date().getFullYear()
		const startYear = 1980
		const endYear = currentYear + 5
		for (let y = startYear; y <= endYear; y++) {
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
		const startYear = 1980
		const index = year - startYear
		this.scrollWheelTo(this.yearWheelTarget.parentElement, index, smooth)
	}

	private scrollMonthTo(month: number, smooth = true) {
		this.scrollWheelTo(this.monthWheelTarget.parentElement, month - 1, smooth)
	}

	onYearScroll(event: Event) {
		const container = event.target as HTMLElement
		const currentYear = new Date().getFullYear()
		const startYear = 1980
		const endYear = currentYear + 5
		const index = this.getIndexFromScroll(container)
		const newYear = startYear + index
		if (newYear !== this.selectedYear && newYear >= startYear && newYear <= endYear) {
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
