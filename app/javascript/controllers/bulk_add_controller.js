import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static values = {
		date: String,
		url: String
	}

	submit(event) {
		const templateId = event.target.value
		if (!templateId || templateId === 'all') return

		const url = this.urlValue.replace(':id', templateId)
		const formData = new FormData()
		formData.append('date', this.dateValue)

		// Rails UJS or fetch
		fetch(url, {
			method: 'POST',
			body: formData,
			headers: {
				'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
				'Accept': 'application/html' // We want a redirect/reload
			}
		}).then(response => {
			if (response.redirected) {
				window.location.href = response.url
			} else {
				window.location.reload()
			}
		})
	}
}
