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

	connect() {
		window.addEventListener('datepicker:open', this.open.bind(this) as any)
		window.addEventListener('datepicker:confirmed', this.onOtherConfirmed.bind(this) as any)
	}

	disconnect() {
		window.removeEventListener('datepicker:open', this.open.bind(this) as any)
		window.removeEventListener('datepicker:confirmed', this.onOtherConfirmed.bind(this) as any)
	}

	open(event: CustomEvent) {
		const { date, trigger } = event.detail
		this.selectedDate = date ? new Date(date) : new Date()
		this.currentTrigger = trigger

		this.modalTarget.showModal()

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

	onOtherConfirmed() {
		// 別のトリガーで確定された場合も自分の選択を同期（任意）
	}

	initialRender() {
		this.scrollAreaTarget.innerHTML = ""
		this.renderedMonths = []

		const now = new Date()
		// 現在の月を中心に前後3ヶ月描画
		const start = new Date(now.getFullYear(), now.getMonth() - 3, 1)

		for (let i = 0; i < 7; i++) {
			const monthDate = new Date(start.getFullYear(), start.getMonth() + i, 1)
			this.renderMonth(monthDate)
		}

		this.scrollToSelected()
	}

	scrollToSelected() {
		setTimeout(() => {
			const date = this.selectedDate || new Date()
			const monthId = `month-${date.getFullYear()}-${date.getMonth() + 1}`
			const element = document.getElementById(monthId)
			if (element) {
				element.scrollIntoView({ block: 'start' })
			}
		}, 100)
	}

	onScroll() {
		const area = this.scrollAreaTarget
		// 下端付近
		if (area.scrollTop + area.clientHeight >= area.scrollHeight - 300) {
			this.loadMore('future')
		}
		// 上端付近
		if (area.scrollTop <= 300) {
			this.loadMore('past')
		}
	}

	loadMore(direction: 'future' | 'past') {
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
			this.renderedMonths.unshift(monthKey)
		} else {
			this.renderedMonths.push(monthKey)
		}

		const monthEl = document.createElement('div')
		monthEl.id = `month-${monthKey}`
		monthEl.className = "mb-12 relative px-4"

		const title = document.createElement('h4')
		title.className = "text-center text-sm font-bold mb-6 sticky top-0 bg-neutral-900/90 backdrop-blur-md py-4 z-20 text-gray-300"
		title.textContent = `${year}/${month + 1}`
		monthEl.appendChild(title)

		// 透かし文字 (大きな数字)
		const bgText = document.createElement('div')
		bgText.className = "absolute inset-0 flex items-center justify-center text-[180px] font-black text-white/[0.03] pointer-events-none z-0 select-none pb-12"
		bgText.textContent = `${month + 1}`
		monthEl.appendChild(bgText)

		const grid = document.createElement('div')
		grid.className = "grid grid-cols-7 gap-y-3 relative z-10"

		const firstDay = new Date(year, month, 1).getDay()
		const daysInMonth = new Date(year, month + 1, 0).getDate()

		for (let i = 0; i < firstDay; i++) {
			grid.appendChild(document.createElement('div'))
		}

		for (let d = 1; d <= daysInMonth; d++) {
			const dayEl = document.createElement('div')
			dayEl.className = "h-12 w-12 mx-auto flex items-center justify-center cursor-pointer rounded-xl transition-all duration-200 active:scale-95 text-base font-medium"
			dayEl.textContent = d.toString()

			const currentDate = new Date(year, month, d)
			if (this.isSameDate(currentDate, this.selectedDate)) {
				dayEl.classList.add('bg-blue-500', 'text-white', 'font-bold', 'shadow-lg', 'shadow-blue-500/30')
			} else {
				dayEl.classList.add('text-gray-400', 'hover:bg-white/5')
			}

			dayEl.onclick = (e) => {
				e.preventDefault()
				this.selectDate(currentDate)
			}
			grid.appendChild(dayEl)
		}

		monthEl.appendChild(grid)

		if (prepend) {
			const currentScrollHeight = this.scrollAreaTarget.scrollHeight
			const currentScrollTop = this.scrollAreaTarget.scrollTop

			this.scrollAreaTarget.prepend(monthEl)

			// スクロール位置の補正
			const newScrollHeight = this.scrollAreaTarget.scrollHeight
			this.scrollAreaTarget.scrollTop = currentScrollTop + (newScrollHeight - currentScrollHeight)
		} else {
			this.scrollAreaTarget.appendChild(monthEl)
		}
	}

	selectDate(date: Date) {
		this.selectedDate = date
		this.updateHighlight()
	}

	updateHighlight() {
		this.scrollAreaTarget.querySelectorAll('.bg-blue-500').forEach(el => {
			el.classList.remove('bg-blue-500', 'text-white', 'font-bold', 'shadow-lg', 'shadow-blue-500/30')
			el.classList.add('text-gray-400', 'hover:bg-white/5')
		})

		if (!this.selectedDate) return
		const year = this.selectedDate.getFullYear()
		const month = this.selectedDate.getMonth() + 1
		const day = this.selectedDate.getDate()

		const monthId = `month-${year}-${month}`
		const monthEl = document.getElementById(monthId)
		if (monthEl) {
			const dayElements = Array.from(monthEl.querySelectorAll('.grid > div')).filter(el => el.textContent !== "")
			const targetEl = dayElements[day - 1] as HTMLElement
			if (targetEl) {
				targetEl.classList.remove('text-gray-400', 'hover:bg-white/5')
				targetEl.classList.add('bg-blue-500', 'text-white', 'font-bold', 'shadow-lg', 'shadow-blue-500/30')
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
