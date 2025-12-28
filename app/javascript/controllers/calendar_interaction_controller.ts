import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static targets = ["detailsFrame", "filterSelect", "day"]
	static values = {
		date: String,
		scope: String,
		filterUser: String
	}

	declare readonly detailsFrameTarget: any // TurboFrame
	declare readonly filterSelectTarget: HTMLSelectElement
	declare readonly dayTargets: HTMLElement[]
	declare dateValue: string
	declare scopeValue: string
	declare filterUserValue: string

	connect() {
		this.updateSelectedDateStyle()
	}

	// Action for Date Links (Grid)
	selectDate(event: Event) {
		event.preventDefault()
		const link = event.currentTarget as HTMLAnchorElement
		const url = new URL(link.href)
		const date = url.searchParams.get("date")

		if (date) {
			this.dateValue = date
			this.updateFrame()
			this.updateSelectedDateStyle()
			this.scrollToDetails()
		}
	}

	updateSelectedDateStyle() {
		// Remove ring from all date cells
		this.dayTargets.forEach((cell: HTMLElement) => {
			cell.classList.remove('ring-2', 'ring-blue-500', 'ring-inset', 'z-10')
		})

		// Add ring to selected date cell
		const selectedCell = this.dayTargets.find((cell: HTMLElement) => {
			const cellDate = cell.dataset.calendarDate
			return cellDate === this.dateValue
		})

		if (selectedCell) {
			selectedCell.classList.add('ring-2', 'ring-blue-500', 'ring-inset', 'z-10')
		}
	}

	// Action for Filter Select
	changeFilter(event: Event) {
		const userId = this.filterSelectTarget.value
		this.filterUserValue = userId
		this.updateFrame()
	}

	updateFrame() {
		const url = new URL("/calendar/daily_view", window.location.origin)
		url.searchParams.set("date", this.dateValue)

		if (this.scopeValue) {
			url.searchParams.set("scope", this.scopeValue)
		}

		if (this.filterUserValue && this.filterUserValue !== 'all') {
			url.searchParams.set("filter_user_id", this.filterUserValue)
		}

		this.detailsFrameTarget.src = url.toString()
	}

	scrollToDetails() {
		if (window.innerWidth < 1024) { // lg breakpoint
			const element = document.getElementById("daily_details")
			if (element) {
				element.scrollIntoView({ behavior: "smooth", block: "start" })
			}
		}
	}
}
