import { Controller } from "@hotwired/stimulus"

/**
 * Side Panel Closer Controller
 *
 * connect時にパネルクローズイベントを発火させ、自身を削除する。
 * Turbo Streamでイベントを発火させたい場合に使用する。
 */
export default class extends Controller {
	connect() {
		window.dispatchEvent(new CustomEvent('side-panel:close'))
		this.element.remove()
	}
}
