class OpeningHours {
    [timespan] $OpenAt
    [timespan] $CloseAt

    OpeningHours([timespan]$OpenAt, [timespan]$CloseAt) {
        $this.OpenAt = $OpenAt
        $this.CloseAt = $CloseAt
    }
}
