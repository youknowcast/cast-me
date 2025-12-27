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
	}

	disconnect() {
		window.removeEventListener('datepicker:open', this.open.bind(this) as any)
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

	initialRender() {
		this.scrollAreaTarget.innerHTML = ""
		this.renderedMonths = []

		const now = new Date()
		// 70%の高さに収まるよう、表示範囲を調整（初期±3ヶ月）
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
				// ヘッダーの高さを考慮して位置調整
				element.scrollIntoView({ block: 'start', behavior: 'instant' as any })
			}
		}, 50)
	}

	onScroll() {
		const area = this.scrollAreaTarget
		if (area.scrollTop + area.clientHeight >= area.scrollHeight - 400) {
			this.loadMore('future')
		}
		if (area.scrollTop <= 400) {
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
		monthEl.className = "mb-10 relative px-4"

		const title = document.createElement('h4')
		title.className = "text-center text-sm font-bold mb-4 sticky top-0 bg-neutral-900/95 backdrop-blur-md py-3 z-20 text-gray-200 border-b border-gray-800/20"
		title.textContent = `${year}年 ${month + 1}月`
		monthEl.appendChild(title)

		// 透かし文字
		const bgText = document.createElement('div')
		bgText.className = "absolute inset-0 flex items-center justify-center text-[160px] font-black text-white/[0.02] pointer-events-none z-0 select-none pb-10"
		bgText.textContent = `${month + 1}`
		monthEl.appendChild(bgText)

		const grid = document.createElement('div')
		grid.className = "grid grid-cols-7 gap-y-2 relative z-10"

		const firstDay = new Date(year, month, 1).getDay()
		const daysInMonth = new Date(year, month + 1, 0).getDate()

		for (let i = 0; i < firstDay; i++) {
			grid.appendChild(document.createElement('div'))
		}

		for (let d = 1; d <= daysInMonth; d++) {
			const dayEl = document.createElement('div')
			// 70%の高さに合わせて少しコンパクトに (h-10 w-10)
			dayEl.className = "h-11 w-11 mx-auto flex items-center justify-center cursor-pointer rounded-full transition-all duration-200 active:scale-90 text-base font-medium"
			dayEl.textContent = d.toString()

			const currentDate = new Date(year, month, d)

			// 今日の日付のスタイル
			const isToday = this.isSameDate(currentDate, new Date())
			if (isToday && !this.isSameDate(currentDate, this.selectedDate)) {
				dayEl.classList.add('text-blue-400', 'font-bold')
			}

			if (this.isSameDate(currentDate, this.selectedDate)) {
				dayEl.classList.add('bg-blue-600', 'text-white', 'font-bold', 'shadow-lg', 'shadow-blue-600/40')
			} else {
				if (!isToday) dayEl.classList.add('text-gray-400')
				dayEl.classList.add('hover:bg-white/5')
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
		this.scrollAreaTarget.querySelectorAll('.bg-blue-600').forEach(el => {
			el.classList.remove('bg-blue-600', 'text-white', 'font-bold', 'shadow-lg', 'shadow-blue-600/40')
			// 元のスタイルに戻す
			const d = parseInt(el.textContent || "0")
			// 親コンテナのIDから日付を推定するのは面倒なので、再描画時に正規化されることを期待するか、
			// ここで全ての要素の状態をチェックし直す。簡略化のためクラスのみ操作。
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
				targetEl.classList.remove('text-gray-400', 'text-blue-400', 'hover:bg-white/5')
				targetEl.classList.add('bg-blue-600', 'text-white', 'font-bold', 'shadow-lg', 'shadow-blue-600/40')
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
