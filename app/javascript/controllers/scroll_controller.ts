import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static targets = ["details"]

	connect() {
		// Optional: could add intersection observer here if needed
	}

	scrollToDetails() {
		if (window.innerWidth < 768) { // md breakpoint
			const detailsElement = document.getElementById("daily_details")
			if (detailsElement) {
				detailsElement.scrollIntoView({ behavior: "smooth", block: "start" })
			}
		}
	}
}
