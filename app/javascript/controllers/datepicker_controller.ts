import { BaseActionSheetController } from "../lib/base_action_sheet_controller"

export default class extends BaseActionSheetController {
	static targets = ["modal", "scrollArea", "loader", "headerTitle", "selectedCount"]

	declare readonly scrollAreaTarget: HTMLElement
	declare readonly loaderTarget: HTMLElement
	declare readonly headerTitleTarget: HTMLElement
	declare readonly selectedCountTarget: HTMLElement
	declare readonly hasSelectedCountTarget: boolean

	private selectedDate: Date | null = null
	private selectedDates: Date[] = []
	private multiple = false
	private renderedMonths: string[] = [] // YYYY-MM
	private isInitialRender = true
	private isLoadingPast = false

	get eventPrefix() {
		return 'datepicker'
	}

	connect() {
		console.log('[Datepicker] connected. Instance:', this)
		super.connect()
		window.addEventListener('monthpicker:confirmed', this.onMonthJump.bind(this) as any)
	}

	disconnect() {
		super.disconnect()
		window.removeEventListener('monthpicker:confirmed', this.onMonthJump.bind(this) as any)
	}

	onOpen(detail: any) {
		const { date, dates, multiple } = detail
		this.multiple = multiple === true
		this.selectedDates = this.multiple && Array.isArray(dates)
			? dates.map((value: string) => this.parseDate(value)).filter((value: Date | null): value is Date => value !== null)
			: []
		this.selectedDate = this.selectedDates[0] || (date ? this.parseDate(date) : null) || new Date()
		if (this.multiple && this.selectedDates.length === 0) this.selectedDates = [this.selectedDate]
		this.updateSelectedCount()

		console.log('[Datepicker] Open called, isInitialRender:', this.isInitialRender)

		if (this.isInitialRender) {
			this.initialRender()
			this.isInitialRender = false
		} else {
			this.updateHighlight()
			this.scrollToSelected()
		}
	}

	onConfirm() {
		if (this.multiple && this.selectedDates.length > 0) {
			return { dates: this.selectedDates.map(date => this.formatDate(date)) }
		}
		if (this.selectedDate) {
			return { date: this.formatDate(this.selectedDate) }
		}
		return null
	}

	openMonthPicker() {
		const target = this.selectedDate || new Date()
		window.dispatchEvent(new CustomEvent('monthpicker:open', {
			detail: {
				date: this.formatDate(target),
				trigger: this.element
			}
		}))
	}

	private onMonthJump(event: CustomEvent) {
		const { year, month, trigger } = event.detail
		if (trigger === this.element) {
			this.jumpToMonth(year, month)
		}
	}

	private jumpToMonth(year: number, month: number) {
		this.renderedMonths = []
		this.scrollAreaTarget.innerHTML = ""

		const start = new Date(year, month - 2, 1) // Start 1 month before to allow smooth scrolling if needed
		for (let i = 0; i < 7; i++) {
			const monthDate = new Date(start.getFullYear(), start.getMonth() + i, 1)
			this.renderMonth(monthDate)
		}

		requestAnimationFrame(() => {
			const monthId = `month-${year}-${month}`
			const element = document.getElementById(monthId)
			if (element) {
				element.scrollIntoView({ block: 'start', behavior: 'instant' as any })
			}
			this.updateHeaderTitle()
		})
	}

	private initialRender() {
		console.log('[Datepicker] initialRender called')
		this.scrollAreaTarget.innerHTML = ""
		this.renderedMonths = []

		const target = this.selectedDate || new Date()
		const start = new Date(target.getFullYear(), target.getMonth() - 3, 1)

		for (let i = 0; i < 7; i++) {
			const monthDate = new Date(start.getFullYear(), start.getMonth() + i, 1)
			this.renderMonth(monthDate)
		}
		console.log('[Datepicker] Rendered months:', this.renderedMonths)

		this.scrollToSelected()
	}

	private scrollToSelected() {
		requestAnimationFrame(() => {
			const date = this.selectedDate || new Date()
			const monthId = `month-${date.getFullYear()}-${date.getMonth() + 1}`
			const element = document.getElementById(monthId)
			if (element) {
				element.scrollIntoView({ block: 'start', behavior: 'instant' as any })
			}
		})
	}

	onScroll() {
		const area = this.scrollAreaTarget
		// Load more future months when near bottom
		if (area.scrollTop + area.clientHeight >= area.scrollHeight - 300) {
			this.loadMore('future')
		}
		// Load more past months when near top
		if (area.scrollTop <= 300 && !this.isLoadingPast) {
			this.loadMore('past')
		}
		this.updateHeaderTitle()
	}

	private updateHeaderTitle() {
		if (!this.headerTitleTarget) return

		// Find which month is mostly visible
		const area = this.scrollAreaTarget
		const areaRect = area.getBoundingClientRect()
		const months = Array.from(area.querySelectorAll('[id^="month-"]'))

		let mostVisibleMonth = months[0]
		let maxVisibleHeight = 0

		months.forEach(month => {
			const rect = month.getBoundingClientRect()
			const visibleTop = Math.max(rect.top, areaRect.top)
			const visibleBottom = Math.min(rect.bottom, areaRect.bottom)
			const visibleHeight = Math.max(0, visibleBottom - visibleTop)

			if (visibleHeight > maxVisibleHeight) {
				maxVisibleHeight = visibleHeight
				mostVisibleMonth = month
			}
		})

		if (mostVisibleMonth) {
			const [_, year, month] = mostVisibleMonth.id.split('-')
			this.headerTitleTarget.textContent = `${year}年${month}月`
		}
	}

	private loadMore(direction: 'future' | 'past') {
		if (this.renderedMonths.length === 0) return

		const lastRendered = direction === 'future'
			? this.renderedMonths[this.renderedMonths.length - 1]
			: this.renderedMonths[0]

		const [year, month] = lastRendered.split('-').map(Number)
		const nextDate = direction === 'future'
			? new Date(year, month, 1)
			: new Date(year, month - 2, 1)

		this.renderMonth(nextDate, direction === 'past')
	}

	private renderMonth(date: Date, prepend = false) {
		const year = date.getFullYear()
		const month = date.getMonth()
		const monthKey = `${year}-${month + 1}`

		if (this.renderedMonths.includes(monthKey)) return

		if (prepend) {
			this.isLoadingPast = true
			this.renderedMonths.unshift(monthKey)
		} else {
			this.renderedMonths.push(monthKey)
		}

		const monthEl = document.createElement('div')
		monthEl.id = `month-${monthKey}`
		monthEl.className = "mb-6 relative px-4"

		// Month/Year header
		const title = document.createElement('h4')
		title.className = "text-center text-base font-bold mb-3 sticky top-0 bg-white/95 backdrop-blur-sm py-3 z-10 text-gray-800"
		title.textContent = `${year}年${month + 1}月`
		monthEl.appendChild(title)

		// Calendar grid
		const grid = document.createElement('div')
		grid.className = "grid grid-cols-7 gap-y-2"

		const firstDay = new Date(year, month, 1).getDay()
		const daysInMonth = new Date(year, month + 1, 0).getDate()

		// Empty cells for days before first of month
		for (let i = 0; i < firstDay; i++) {
			grid.appendChild(document.createElement('div'))
		}

		const today = new Date()
		for (let d = 1; d <= daysInMonth; d++) {
			const dayEl = document.createElement('button')
			dayEl.type = 'button'
			dayEl.className = "h-10 w-10 mx-auto flex items-center justify-center cursor-pointer rounded-full transition-all duration-150 text-sm font-medium touch-manipulation"
			dayEl.textContent = d.toString()
			dayEl.setAttribute('data-date', this.formatDate(new Date(year, month, d)))

			const currentDate = new Date(year, month, d)
			const dayOfWeek = currentDate.getDay()

			// Sunday: red, Saturday: blue
			if (dayOfWeek === 0) {
				dayEl.classList.add('text-red-500')
			} else if (dayOfWeek === 6) {
				dayEl.classList.add('text-blue-500')
			} else {
				dayEl.classList.add('text-gray-700')
			}

			const isToday = this.isSameDate(currentDate, today)
			if (isToday && !this.isDateSelected(currentDate)) {
				dayEl.classList.add('ring-2', 'ring-blue-400', 'ring-inset')
			}

			if (this.isDateSelected(currentDate)) {
				dayEl.classList.remove('text-gray-700', 'text-red-500', 'text-blue-500')
				dayEl.classList.add('bg-blue-500', 'text-white', 'font-bold', 'shadow-md')
			} else {
				dayEl.classList.add('active:bg-gray-100')
			}

			dayEl.addEventListener('click', (e) => {
				e.preventDefault()
				this.selectDate(currentDate)
			})
			grid.appendChild(dayEl)
		}

		monthEl.appendChild(grid)

		if (prepend) {
			const prevScrollHeight = this.scrollAreaTarget.scrollHeight
			const prevScrollTop = this.scrollAreaTarget.scrollTop
			this.scrollAreaTarget.prepend(monthEl)
			// Maintain scroll position after prepending
			requestAnimationFrame(() => {
				const newScrollHeight = this.scrollAreaTarget.scrollHeight
				this.scrollAreaTarget.scrollTop = prevScrollTop + (newScrollHeight - prevScrollHeight)
				this.isLoadingPast = false
			})
		} else {
			this.scrollAreaTarget.appendChild(monthEl)
		}
	}

	private selectDate(date: Date) {
		if (this.multiple) {
			const selectedIndex = this.selectedDates.findIndex(selected => this.isSameDate(selected, date))
			if (selectedIndex >= 0 && this.selectedDates.length > 1) {
				this.selectedDates.splice(selectedIndex, 1)
				// Move the anchor to a still-selected date, never the one just removed
				this.selectedDate = this.selectedDates[this.selectedDates.length - 1]
			} else if (selectedIndex < 0) {
				this.selectedDates.push(date)
				this.selectedDate = date
			}
		} else {
			this.selectedDate = date
		}
		this.updateSelectedCount()
		this.updateHighlight()
	}

	private updateHighlight() {
		const today = new Date()
		const ringClasses = ['ring-2', 'ring-blue-400', 'ring-inset']

		// Remove old selection
		this.scrollAreaTarget.querySelectorAll('[data-date]').forEach(el => {
			el.classList.remove('bg-blue-500', 'text-white', 'font-bold', 'shadow-md')
			// Restore original color (parse as local time, matching renderMonth)
			const dateStr = el.getAttribute('data-date')
			const cellDate = dateStr ? this.parseDate(dateStr) : null
			const dow = cellDate ? cellDate.getDay() : -1
			if (dow === 0) el.classList.add('text-red-500')
			else if (dow === 6) el.classList.add('text-blue-500')
			else el.classList.add('text-gray-700')
			el.classList.add('active:bg-gray-100')

			// Restore the today ring for unselected today, matching renderMonth
			if (cellDate && this.isSameDate(cellDate, today) && !this.isDateSelected(cellDate)) {
				el.classList.add(...ringClasses)
			} else {
				el.classList.remove(...ringClasses)
			}
		})

		const dates = this.multiple ? this.selectedDates : [this.selectedDate].filter((date): date is Date => date !== null)
		dates.forEach(date => {
			const targetEl = this.scrollAreaTarget.querySelector(`[data-date="${this.formatDate(date)}"]`)
			if (!targetEl) return

			targetEl.classList.remove('text-gray-700', 'text-red-500', 'text-blue-500', 'active:bg-gray-100', ...ringClasses)
			targetEl.classList.add('bg-blue-500', 'text-white', 'font-bold', 'shadow-md')
		})
	}

	private isDateSelected(date: Date) {
		return this.multiple
			? this.selectedDates.some(selected => this.isSameDate(selected, date))
			: this.isSameDate(date, this.selectedDate)
	}

	private updateSelectedCount() {
		if (!this.hasSelectedCountTarget) return

		this.selectedCountTarget.classList.toggle('hidden', !this.multiple)
		this.selectedCountTarget.textContent = this.multiple ? `${this.selectedDates.length}日` : ''
	}

	private isSameDate(d1: Date, d2: Date | null) {
		if (!d2) return false
		return d1.getFullYear() === d2.getFullYear() &&
			d1.getMonth() === d2.getMonth() &&
			d1.getDate() === d2.getDate()
	}

	private formatDate(date: Date) {
		const y = date.getFullYear()
		const m = String(date.getMonth() + 1).padStart(2, '0')
		const d = String(date.getDate()).padStart(2, '0')
		return `${y}-${m}-${d}`
	}

	private parseDate(value: string) {
		const match = value.match(/^(\d{4})-(\d{2})-(\d{2})$/)
		if (!match) return null

		const date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]))
		return this.formatDate(date) === value ? date : null
	}
}
