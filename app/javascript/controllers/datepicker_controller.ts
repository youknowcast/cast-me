import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static targets = ["modal", "scrollArea", "loader"]

	declare readonly modalTarget: HTMLDialogElement
	declare readonly scrollAreaTarget: HTMLElement
	declare readonly loaderTarget: HTMLElement

	private selectedDate: Date | null = null
	private renderedMonths: string[] = [] // YYYY-MM
	private currentTrigger: any = null
	private isInitialRender = true
	private isLoadingPast = false

	connect() {
		console.log('[Datepicker] Controller connected')
		window.addEventListener('datepicker:open', this.open.bind(this) as any)
		// Handle backdrop click (clicking outside modal-box) to confirm
		this.modalTarget.addEventListener('click', this.handleBackdropClick.bind(this))
	}

	disconnect() {
		window.removeEventListener('datepicker:open', this.open.bind(this) as any)
		this.modalTarget.removeEventListener('click', this.handleBackdropClick.bind(this))
	}

	handleBackdropClick(event: MouseEvent) {
		// If click target is the dialog itself (backdrop), not the modal-box content, confirm and close
		if (event.target === this.modalTarget) {
			this.confirm()
		}
	}

	open(event: CustomEvent) {
		console.log('[Datepicker] Open called with event:', event.detail)
		const { date, trigger } = event.detail
		this.selectedDate = date ? new Date(date) : new Date()
		this.currentTrigger = trigger

		this.modalTarget.showModal()
		console.log('[Datepicker] Modal shown, isInitialRender:', this.isInitialRender)

		if (this.isInitialRender) {
			this.initialRender()
			this.isInitialRender = false
		} else {
			this.updateHighlight()
			this.scrollToSelected()
		}
	}

	close() {
		this.modalTarget.close()
	}

	confirm() {
		if (this.selectedDate && this.currentTrigger) {
			window.dispatchEvent(new CustomEvent('datepicker:confirmed', {
				detail: {
					date: this.formatDate(this.selectedDate),
					trigger: this.currentTrigger
				}
			}))
		}
		this.close()
	}

	initialRender() {
		console.log('[Datepicker] initialRender called, scrollAreaTarget:', this.scrollAreaTarget)
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

	scrollToSelected() {
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
	}

	loadMore(direction: 'future' | 'past') {
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

	renderMonth(date: Date, prepend = false) {
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
			if (isToday && !this.isSameDate(currentDate, this.selectedDate)) {
				dayEl.classList.add('ring-2', 'ring-blue-400', 'ring-inset')
			}

			if (this.isSameDate(currentDate, this.selectedDate)) {
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

	selectDate(date: Date) {
		this.selectedDate = date
		this.updateHighlight()
	}

	updateHighlight() {
		// Remove old selection
		this.scrollAreaTarget.querySelectorAll('.bg-blue-500').forEach(el => {
			el.classList.remove('bg-blue-500', 'text-white', 'font-bold', 'shadow-md')
			// Restore original color
			const dateStr = el.getAttribute('data-date')
			if (dateStr) {
				const d = new Date(dateStr)
				const dow = d.getDay()
				if (dow === 0) el.classList.add('text-red-500')
				else if (dow === 6) el.classList.add('text-blue-500')
				else el.classList.add('text-gray-700')
			} else {
				el.classList.add('text-gray-700')
			}
			el.classList.add('active:bg-gray-100')
		})

		if (!this.selectedDate) return
		const year = this.selectedDate.getFullYear()
		const month = this.selectedDate.getMonth() + 1
		const day = this.selectedDate.getDate()

		const monthId = `month-${year}-${month}`
		const monthEl = document.getElementById(monthId)
		if (monthEl) {
			const buttons = Array.from(monthEl.querySelectorAll('button'))
			const targetEl = buttons.find(btn => btn.textContent === day.toString())
			if (targetEl) {
				targetEl.classList.remove('text-gray-700', 'text-red-500', 'text-blue-500', 'active:bg-gray-100')
				targetEl.classList.add('bg-blue-500', 'text-white', 'font-bold', 'shadow-md')
			}
		}
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
}
