class C {
    [string]$Name

    C([string]$Name) {
        $this.Name = $Name
    }

    [string]GetInfo() {
        return "Name: $($this.Name)"
    }
}

class B : C {
    [int]$Age

    B([string]$Name, [int]$Age) : base($Name) {
        $this.Age = $Age
    }

    [string]GetInfo() {
        # Cast $this to the parent class (C) to call its GetInfo()
        return "$(([C]$this).GetInfo()), Age: $($this.Age)"
    }
}

class A : B {
    [string]$Role

    A([string]$Name, [int]$Age, [string]$Role) : base($Name, $Age) {
        $this.Role = $Role
    }

    [string]GetInfo() {
        # Cast $this to B to call B’s GetInfo(), which itself calls C’s GetInfo()
        return "$(([B]$this).GetInfo()), Role: $($this.Role)"
    }
}

# Creating and testing an instance
$person = [A]::new('John Doe', 30, 'Manager')
$person.GetInfo()
