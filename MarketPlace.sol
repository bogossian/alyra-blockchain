pragma solidity ^0.5.7;
import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/math/SafeMath.sol";
pragma experimental ABIEncoderV2;

contract MarketPlace {
    
    using SafeMath for uint;
    
    struct illustrateur {
        string nom;
        uint8 reputation;
        address payable addr;
    }   
    
    struct demande {
        uint idDemande;
        address addrEntreprise;
        uint remuneration;
        uint delai;
        string description;
        etatDemande etat;
        uint8 reputationMinimum;
        uint dateDebut;
        uint dateLivraison;
        bytes32 hashUrl;
    }
    
    enum etatDemande {
        OUVERTE,ENCOURS,LIVREE,ACCEPTEE,REFUSEE
    }
    
    uint8 sanctionRetard = 1;
    
    illustrateur[] illustrateurs;
    mapping(address => bool) addrIllustrateursMap;
    mapping(address => illustrateur) illustrateursMap;
    mapping(address => bool) bannisMap;
    mapping(address => bool) adminsMap;
    mapping(address => bool) entreprisesMap;
    demande[] demandes;
    mapping(uint => demande) demandesMap;
    mapping(address => demande[]) illustrateurDemandesMap;
    mapping(uint => illustrateur) demandesIllustrateursMap;
    mapping(address => uint[]) demandesAttribuees;
    address payable addrPlateforme;
    mapping(uint => bool) demandesSanctionsMap;
    
    // Mécanisme de réputation.
    function inscriptionIllustrateur(string memory nom, address payable addr) public {
        
        require(bannisMap[addr] == false, "Vous avez été banni de la place de marché.");
        require(addrIllustrateursMap[addr] == false, "Vous êtes déjà sur la place de marché.");
        require(bytes(nom).length > 0, "Vous devez renseigner un nom.");
        
        illustrateurs.push(illustrateur(nom, 1, addr));
        addrIllustrateursMap[addr] = true;
        
        if(illustrateurs.length == 1)
        {
            adminsMap[addr] = true;
        }
    }
    
    function bannirIllustrateur(address addr) public {
        
        require(adminsMap[msg.sender] == true,"Vous n'êtes pas administrateur.");
        bannisMap[addr] = true;
        addrIllustrateursMap[addr] = false;
        for (uint i=0; i<illustrateurs.length; i++) {
            if(illustrateurs[i].addr == addr) {
                illustrateurs[i].reputation = 0;
                return;
            }
        }    
    }
    
    // Demandes.
    
    function listerDemandes() view public returns (demande[] memory) {
        return demandes;
    }
    
    function ajouterDemande(uint remuneration, uint delai, string memory description, uint8 reputationMinimum) public {
        require(entreprisesMap[msg.sender] == true, "Vous n'êtes pas inscrit sur la plateforme comme entreprise.");
        uint idDemande = demandes.length;
        bytes32 hashUrl;
        demandes.push(demande(idDemande,msg.sender, remuneration, delai, description, etatDemande.OUVERTE, reputationMinimum, 0, 0, hashUrl));
        
        uint montant = uint(remuneration.mul(uint(1)));
        
        addrPlateforme.transfer(montant);
    }
    
    // Contractualisation.
    function postuler(uint idDemande) public {
        
        require(illustrateurEstInscrit(msg.sender) == true, "Vous devez être inscrit sur la plateforme pour postuler.");
        
        demande memory demandePostulee = demandesMap[idDemande];
        require(demandePostulee.idDemande > 0, "Cette demande n'existe pas.");
        
        illustrateur memory postulant = illustrateursMap[msg.sender];
        require(postulant.reputation >= demandePostulee.reputationMinimum, "Vous n'avez pas une assez bonne réputation pour cette demande.");
        
        demandesIllustrateursMap[idDemande] = postulant;
    }
    
    function accepterOffre(uint idDemande, address addrPostulant) public {
        demande storage demandeAAttibuer = demandesMap[idDemande];
        require(demandeAAttibuer.idDemande > 0, "Cette demande n'existe pas.");
        require(demandeAAttibuer.addrEntreprise == msg.sender, "Vous n'êtes pas le propriétaire de cette demande.");
        illustrateur memory postulant = demandesIllustrateursMap[idDemande];
        require(bytes(postulant.nom).length > 0, "Cet illustrateur n'a pas postulé à cette demande.");
        
        demandeAAttibuer.etat = etatDemande.ENCOURS;
        demandeAAttibuer.dateDebut = now;
        demandesAttribuees[addrPostulant].push(idDemande); 
    }
    
    function livrer(uint idDemande, string memory url) public {
        
        demande storage demandeLivree = demandesMap[idDemande];
        require(demandeLivree.idDemande > 0, "Cette demande n'existe pas.");
        bool attribue = false;
        for(uint i=0; i<demandesAttribuees[msg.sender].length; i++){
            if(demandesAttribuees[msg.sender][i] == idDemande){
                attribue == true;
                return;
            }
        }
        require(attribue == true, "Cette demande ne vous était pas attribuée.");
        demandeLivree.hashUrl = keccak256(abi.encodePacked(url));
        demandeLivree.etat = etatDemande.LIVREE;
        demandeLivree.dateLivraison = now;
        illustrateur storage livreur = illustrateursMap[msg.sender];
        livreur.reputation = livreur.reputation + 1;
        if((demandeLivree.dateLivraison - demandeLivree.dateDebut) > demandeLivree.delai){
            demandesSanctionsMap[demandeLivree.idDemande] = true;
        }
    }
    
    function sanctionnerRetard(uint idDemande) public {
        demande memory demandeEnRetard = demandesMap[idDemande];
        require(demandeEnRetard.idDemande > 0, "Cette demande n'existe pas");
        require(demandeEnRetard.addrEntreprise == msg.sender, "Vous ne pouvez pas appliquer de sanction pour cette demande");
        require(demandesSanctionsMap[idDemande] == true, "Cette demande n'a pas été livrée en retard.");
        illustrateur storage sanctionne = demandesIllustrateursMap[idDemande];
        sanctionne.reputation = sanctionRetard;
        demandesSanctionsMap[idDemande] = false;
    }
    
    function retirerFond(uint idDemande) public {
        
        demande storage demandeFermee = demandesMap[idDemande];
        require(demandeFermee.idDemande > 0, "Cette demande n'existe pas.");
        bool attribue = false;
        for(uint i=0; i<demandesAttribuees[msg.sender].length; i++){
            if(demandesAttribuees[msg.sender][i] == idDemande){
                attribue == true;
                return;
            }
        }
        require(attribue == true, "Cette demande ne vous était pas attribuée.");
        require(demandeFermee.etat == etatDemande.LIVREE, "Cette demande n'est pas encore fermée.");
        
        msg.sender.transfer(demandeFermee.remuneration);
    }
    
    function illustrateurEstInscrit(address addr) public view returns(bool) {
        illustrateur memory inscrit = illustrateursMap[addr];
        return inscrit.addr == addr;
    }
}