//
//  CreateAlbumView.swift
//  Sensic
//
//  Created by Maram Ibrahim  on 04/12/1447 AH.
//

import SwiftUI
 struct CreateAlbumView: View {

    @Bindable var vm: AlbumsViewModel

    var body: some View {

        VStack(spacing: 22) {

            VStack(alignment: .leading, spacing: 10) {

                Text("Name Album")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                Text("Enter a name for this album.")
                    .foregroundStyle(Color("tertiary"))

                TextField("", text: $vm.albumName)
                    .foregroundStyle(.white)
                    .padding()
                    .background(
                        Capsule()
                            .fill(Color("tertiary"))
                        
                    )
            }

            HStack(spacing: 14) {

                Button {
                    vm.showCreateAlbum = false
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule().fill(Color("tertiary").opacity(0.35)))
                        .foregroundStyle(.white)
                }

                Button {
                    vm.createAlbum()
                } label: {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule().fill(Color("tertiary").opacity(0.35)))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 34)
                .fill(Color("Black"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34)
                .stroke(Color("MainPurple").opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 18)
    }
}

#Preview {
    CreateAlbumView(vm: AlbumsViewModel())
}
