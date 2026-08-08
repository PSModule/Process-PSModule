class ZetaCirculationNode {
    [string] $Id
    [AlphaCirculationNode] $Previous

    ZetaCirculationNode([string]$Id, [AlphaCirculationNode]$Previous) {
        $this.Id = $Id
        $this.Previous = $Previous
    }
}
