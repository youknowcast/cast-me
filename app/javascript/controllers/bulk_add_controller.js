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
				'Accept': 'text/html'
			}
		}).then(response => {
			if (response.ok) {
				// Use Turbo or direct location update to refresh the page
				const currentUrl = new URL(window.location.href)
				window.location.href = currentUrl.toString()
			} else {
				console.error('Bulk add failed', response)
				alert('一括登録に失敗しました。')
			}
		}).catch(error => {
			console.error('Network error during bulk add', error)
			alert('ネットワークエラーが発生しました。')
		}).finally(() => {
			// Reset the selector value so it can be triggered again
			event.target.value = ''
		})
	}
}
