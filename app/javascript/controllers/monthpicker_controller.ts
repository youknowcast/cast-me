import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static targets = ["modal", "yearWheel", "monthWheel", "yearValue", "monthValue"]

	declare readonly modalTarget: HTMLDialogElement
	declare readonly yearWheelTarget: HTMLElement
	declare readonly monthWheelTarget: HTMLElement
	declare readonly yearValueTarget: HTMLElement
	declare readonly monthValueTarget: HTMLElement

	private selectedYear = new Date().getFullYear()
	private selectedMonth = new Date().getMonth() + 1
	private currentTrigger: any = null
	private itemHeight = 44
	private baseUrl = ""

	connect() {
		window.addEventListener('monthpicker:open', this.open.bind(this) as any)
		this.modalTarget.addEventListener('click', this.handleBackdropClick.bind(this))
	}

	disconnect() {
		window.removeEventListener('monthpicker:open', this.open.bind(this) as any)
		this.modalTarget.removeEventListener('click', this.handleBackdropClick.bind(this))
	}

	handleBackdropClick(event: MouseEvent) {
		if (event.target === this.modalTarget) {
			this.confirm()
		}
	}

	open(event: CustomEvent) {
		const { date, trigger, baseUrl } = event.detail
		this.currentTrigger = trigger
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
		this.modalTarget.showModal()
		this.scrollToSelected()
	}

	close() {
		this.modalTarget.close()
	}

	confirm() {
		if (this.currentTrigger && this.baseUrl) {
			const dateStr = `${this.selectedYear}-${String(this.selectedMonth).padStart(2, '0')}-01`
			const url = new URL(this.baseUrl, window.location.origin)
			url.searchParams.set('date', dateStr)
			window.location.href = url.toString()
		}
		this.close()
	}

	renderWheels() {
		this.yearWheelTarget.innerHTML = ''
		this.monthWheelTarget.innerHTML = ''

		// Create year items (current year -5 to +5)
		const currentYear = new Date().getFullYear()
		for (let y = currentYear - 5; y <= currentYear + 5; y++) {
			const item = this.createWheelItem(y, 'year')
			this.yearWheelTarget.appendChild(item)
		}

		// Create month items (1-12)
		for (let m = 1; m <= 12; m++) {
			const item = this.createWheelItem(m, 'month')
			this.monthWheelTarget.appendChild(item)
		}

		this.updateDisplay()
	}

	createWheelItem(value: number, type: 'year' | 'month'): HTMLElement {
		const item = document.createElement('button')
		item.type = 'button'
		item.className = 'w-full h-11 flex items-center justify-center text-xl font-medium text-gray-400 transition-all duration-150 touch-manipulation'

		if (type === 'year') {
			item.textContent = String(value) + '年'
		} else {
			item.textContent = String(value) + '月'
		}
		item.dataset.value = String(value)

		item.addEventListener('click', () => {
			if (type === 'year') {
				this.selectedYear = value
				this.scrollYearTo(value)
			} else {
				this.selectedMonth = value
				this.scrollMonthTo(value)
			}
			this.updateDisplay()
		})

		return item
	}

	scrollToSelected() {
		requestAnimationFrame(() => {
			this.scrollYearTo(this.selectedYear, false)
			this.scrollMonthTo(this.selectedMonth, false)
		})
	}

	scrollYearTo(year: number, smooth = true) {
		const container = this.yearWheelTarget.parentElement
		if (container) {
			const currentYear = new Date().getFullYear()
			const index = year - (currentYear - 5)
			const scrollTop = index * this.itemHeight
			container.scrollTo({
				top: scrollTop,
				behavior: smooth ? 'smooth' : 'instant' as any
			})
		}
	}

	scrollMonthTo(month: number, smooth = true) {
		const container = this.monthWheelTarget.parentElement
		if (container) {
			const scrollTop = (month - 1) * this.itemHeight
			container.scrollTo({
				top: scrollTop,
				behavior: smooth ? 'smooth' : 'instant' as any
			})
		}
	}

	onYearScroll(event: Event) {
		const container = event.target as HTMLElement
		const currentYear = new Date().getFullYear()
		const index = Math.round(container.scrollTop / this.itemHeight)
		const newYear = (currentYear - 5) + index
		if (newYear !== this.selectedYear && newYear >= currentYear - 5 && newYear <= currentYear + 5) {
			this.selectedYear = newYear
			this.updateDisplay()
		}
	}

	onMonthScroll(event: Event) {
		const container = event.target as HTMLElement
		const newMonth = Math.round(container.scrollTop / this.itemHeight) + 1
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

	updateDisplay() {
		this.yearValueTarget.textContent = String(this.selectedYear)
		this.monthValueTarget.textContent = String(this.selectedMonth).padStart(2, '0')

		const currentYear = new Date().getFullYear()

		// Update visual styles for year wheel
		this.yearWheelTarget.querySelectorAll('button').forEach((btn) => {
			const btnYear = parseInt(btn.dataset.value || '0')
			if (btnYear === this.selectedYear) {
				btn.classList.remove('text-gray-400')
				btn.classList.add('text-gray-900', 'font-bold', 'text-2xl')
			} else {
				btn.classList.remove('text-gray-900', 'font-bold', 'text-2xl')
				btn.classList.add('text-gray-400')
			}
		})

		// Update visual styles for month wheel
		this.monthWheelTarget.querySelectorAll('button').forEach((btn) => {
			const btnMonth = parseInt(btn.dataset.value || '0')
			if (btnMonth === this.selectedMonth) {
				btn.classList.remove('text-gray-400')
				btn.classList.add('text-gray-900', 'font-bold', 'text-2xl')
			} else {
				btn.classList.remove('text-gray-900', 'font-bold', 'text-2xl')
				btn.classList.add('text-gray-400')
			}
		})
	}
}
