module oliveharvest::extraction {
    use iota::object::{Self as obj, UID};
    use iota::tx_context::{Self as ctx, TxContext};
    use iota::event::{Self as evt};
    use oliveharvest::harvest::{Self as harvest, Harvest};

    // ✅ Struct pour l'huile d'olive avec toutes les infos
    public struct OliveOil has key, store {
        id: object::UID,
        // Informations de la récolte originale
        original_farmer: address,
        harvest_date: u64,
        harvest_quantity: u64,
        olive_type: vector<u8>,
        harvest_method: vector<u8>,
        harvest_note: vector<u8>,
        // Informations d'extraction
        extraction_factory: address,
        extraction_date: u64,
        extraction_method: vector<u8>,
        extraction_temperature: u64,
        extraction_note: vector<u8>,
        // Quantité d'huile produite
        oil_quantity: u64,
    }

    // ✅ Event pour tracer l'extraction
    public struct OilExtracted has copy, drop {
        oil_id: address,
        harvest_id: address,
        original_farmer: address,
        extraction_factory: address,
        harvest_date: u64,
        extraction_date: u64,
        harvest_quantity: u64,
        oil_quantity: u64,
        olive_type: vector<u8>,
        harvest_method: vector<u8>,
        extraction_method: vector<u8>,
        extraction_temperature: u64,
    }

    // ✅ Fonction d'extraction qui consume la Harvest et produit l'OliveOil
    public entry fun extract_oil(
        harvest: Harvest,
        extraction_date: u64,
        extraction_method: vector<u8>,
        extraction_temperature: u64,
        extraction_note: vector<u8>,
        oil_quantity: u64,
        ctx: &mut tx_context::TxContext,
    ) {
        let extraction_factory = ctx::sender(ctx);
        
        // Récupérer les infos de la récolte avant de la consommer
        let harvest_id = harvest::get_harvest_id(&harvest);
        let (
            original_farmer,
            harvest_date,
            harvest_quantity,
            olive_type,
            harvest_method,
            harvest_note,
            _destination
        ) = harvest::get_harvest_info(&harvest);

        // Copier les vecteurs
        let olive_type_copy = *olive_type;
        let harvest_method_copy = *harvest_method;
        let harvest_note_copy = *harvest_note;
        let extraction_method_copy = extraction_method;
        let extraction_note_copy = extraction_note;

        // Détruire la Harvest (elle est consumée) en utilisant unpack_harvest
        let (id, _farmer, _date, _quantity, _olive_type, _method, _note, _destination) = harvest::unpack_harvest(harvest);
        obj::delete(id);

        // Créer l'huile d'olive
        let oil_id = obj::new(ctx);
        let oil_id_address = obj::uid_to_address(&oil_id);

        let olive_oil = OliveOil {
            id: oil_id,
            original_farmer,
            harvest_date,
            harvest_quantity,
            olive_type: olive_type_copy,
            harvest_method: harvest_method_copy,
            harvest_note: harvest_note_copy,
            extraction_factory,
            extraction_date,
            extraction_method: extraction_method_copy,
            extraction_temperature,
            extraction_note: extraction_note_copy,
            oil_quantity,
        };

        // ✅ Émission de l'événement
        evt::emit(OilExtracted {
            oil_id: oil_id_address,
            harvest_id,
            original_farmer,
            extraction_factory,
            harvest_date,
            extraction_date,
            harvest_quantity,
            oil_quantity,
            olive_type: olive_type_copy,
            harvest_method: harvest_method_copy,
            extraction_method: extraction_method_copy,
            extraction_temperature,
        });

        // L'huile reste dans l'usine (transfer vers l'usine)
        iota::transfer::transfer(olive_oil, extraction_factory);
    }

    // ✅ Getter pour toutes les infos de l'huile
    public fun get_oil_info(oil: &OliveOil): (
        address,     // original_farmer
        u64,         // harvest_date
        u64,         // harvest_quantity
        &vector<u8>, // olive_type
        &vector<u8>, // harvest_method
        &vector<u8>, // harvest_note
        address,     // extraction_factory
        u64,         // extraction_date
        &vector<u8>, // extraction_method
        u64,         // extraction_temperature
        &vector<u8>, // extraction_note
        u64,         // oil_quantity
    ) {
        (
            oil.original_farmer,
            oil.harvest_date,
            oil.harvest_quantity,
            &oil.olive_type,
            &oil.harvest_method,
            &oil.harvest_note,
            oil.extraction_factory,
            oil.extraction_date,
            &oil.extraction_method,
            oil.extraction_temperature,
            &oil.extraction_note,
            oil.oil_quantity,
        )
    }

    // ✅ Getter pour l'ID de l'huile
    public fun get_oil_id(oil: &OliveOil): address {
        obj::uid_to_address(&oil.id)
    }

    // ✅ Getter pour vérifier si une usine est propriétaire
    public fun is_factory_owner(oil: &OliveOil, factory_address: address): bool {
        oil.extraction_factory == factory_address
    }
}