class MemberAccount {
    [string] $MemberId
    [string] $DisplayName
    [ReadingList] $ReadingList

    MemberAccount([string]$MemberId, [string]$DisplayName, [ReadingList]$ReadingList) {
        $this.MemberId = $MemberId
        $this.DisplayName = $DisplayName
        $this.ReadingList = $ReadingList
    }
}
