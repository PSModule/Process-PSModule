class AlphaCirculationNode {
    [string] $Id
    [ZetaCirculationNode] $Next

    AlphaCirculationNode([string]$Id, [ZetaCirculationNode]$Next) {
        $this.Id = $Id
        $this.Next = $Next
    }
}
