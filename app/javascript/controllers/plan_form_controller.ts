import { Controller } from "@hotwired/stimulus"

/**
 * Plan Form Controller
 *
 * 予定フォームの開始時刻/終了時刻の連動処理を行う
 * - 開始時刻が選択されたとき、終了時刻が未設定または開始時刻より前なら上書き
 * - 終了時刻が選択されたとき、開始時刻が未設定または終了時刻より後なら上書き
 */
export default class extends Controller {
	static targets = ["startTimeInput", "startTimeDisplay", "endTimeInput", "endTimeDisplay"]

	declare readonly startTimeInputTarget: HTMLInputElement
	declare readonly startTimeDisplayTarget: HTMLElement
	declare readonly endTimeInputTarget: HTMLInputElement
	declare readonly endTimeDisplayTarget: HTMLElement

	declare readonly hasStartTimeInputTarget: boolean
	declare readonly hasEndTimeInputTarget: boolean
	declare readonly hasStartTimeDisplayTarget: boolean
	declare readonly hasEndTimeDisplayTarget: boolean

	onStartTimeChange(_event: Event) {
		if (!this.hasStartTimeInputTarget || !this.hasEndTimeInputTarget) return

		const startTime = this.startTimeInputTarget.value
		const endTime = this.endTimeInputTarget.value

		if (!startTime) return

		// 終了時刻が未設定、または開始時刻より前の場合は終了時刻を上書き
		if (!endTime || this.compareTimes(endTime, startTime) < 0) {
			this.endTimeInputTarget.value = startTime
			this.updateEndTimeDisplay(startTime)
		}
	}

	onEndTimeChange(_event: Event) {
		if (!this.hasStartTimeInputTarget || !this.hasEndTimeInputTarget) return

		const startTime = this.startTimeInputTarget.value
		const endTime = this.endTimeInputTarget.value

		if (!endTime) return

		// 開始時刻が未設定、または終了時刻より後の場合は開始時刻を上書き
		if (!startTime || this.compareTimes(startTime, endTime) > 0) {
			this.startTimeInputTarget.value = endTime
			this.updateStartTimeDisplay(endTime)
		}
	}

	/**
	 * 時刻を比較する
	 * @param time1 HH:MM形式の時刻
	 * @param time2 HH:MM形式の時刻
	 * @returns time1 < time2 なら負、time1 > time2 なら正、等しければ0
	 */
	private compareTimes(time1: string, time2: string): number {
		const [h1, m1] = time1.split(':').map(Number)
		const [h2, m2] = time2.split(':').map(Number)

		if (h1 !== h2) return h1 - h2
		return m1 - m2
	}

	private updateStartTimeDisplay(time: string) {
		if (this.hasStartTimeDisplayTarget) {
			this.startTimeDisplayTarget.textContent = time || '--:--'
		}
	}

	private updateEndTimeDisplay(time: string) {
		if (this.hasEndTimeDisplayTarget) {
			this.endTimeDisplayTarget.textContent = time || '--:--'
		}
	}
}
