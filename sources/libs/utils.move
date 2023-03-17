module hyperex::utils {
    use std::type_name;
    use std::vector;

    ///@todo review performance ? gas
    public fun genPoolName<X, Y, Curve>(): vector<u8>{
        let x = std::ascii::as_bytes(&type_name::into_string(type_name::get<X>()));
        let y = std::ascii::as_bytes(&type_name::into_string(type_name::get<Y>()));
        let curve = std::ascii::as_bytes(&type_name::into_string(type_name::get<Curve>()));
        let name = vector::empty<u8>();
        vector::append(&mut name, *x);
        vector::append(&mut name, *y);
        vector::append(&mut name, *curve);
        name
    }
}
